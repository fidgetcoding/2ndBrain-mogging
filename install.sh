#!/usr/bin/env bash
#
# 2ndBrain-mogging — installer
#
# Installs skills, commands, agents, Stop-hook, and launchd jobs for the
# 2ndBrain mogging plugin. Default behavior is DRY RUN. Nothing is written
# to disk or launchd unless --apply is passed.
#
# Usage:
#   install.sh [--vault PATH] [--apply] [--dry-run] [--no-launchd]
#              [--skip-tests] [--verbose] [--merge-stop]
#
# NEVER uses `set -x`. Settings.json contents must never be echoed
# or logged. This script handles secrets-adjacent data.
#

set -euo pipefail
IFS=$'\n\t'

# ---- resolve paths -----------------------------------------------------------

# Resolve the repo root (directory containing this script).
SCRIPT_PATH="${BASH_SOURCE[0]}"
while [[ -L "$SCRIPT_PATH" ]]; do
  SCRIPT_DIR="$(cd -P "$(dirname "$SCRIPT_PATH")" >/dev/null 2>&1 && pwd)"
  SCRIPT_PATH="$(readlink "$SCRIPT_PATH")"
  [[ "$SCRIPT_PATH" != /* ]] && SCRIPT_PATH="$SCRIPT_DIR/$SCRIPT_PATH"
done
REPO_ROOT="$(cd -P "$(dirname "$SCRIPT_PATH")" >/dev/null 2>&1 && pwd)"
export REPO_ROOT

CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
BACKUP_DIR_ROOT="$CLAUDE_HOME/.backups"
SETTINGS_PATH="$CLAUDE_HOME/settings.json"
LAUNCHAGENTS_DIR="$HOME/Library/LaunchAgents"
CLAUDE_MEMORY_SRC="$CLAUDE_HOME/projects/-Users-nathandavidovich-Desktop-WORK-OBSIDIAN-2ndBrain/memory"

# ---- flags -------------------------------------------------------------------

VAULT=""
APPLY=0
DRY_RUN=1
NO_LAUNCHD=0
SKIP_TESTS=0
VERBOSE=0
MERGE_STOP=0

usage() {
  cat <<'USAGE'
Usage: install.sh [options]

Options:
  --vault PATH     Absolute path to the Obsidian vault (required with --apply)
  --apply          Execute changes (default is dry-run)
  --dry-run        Simulate only (default)
  --no-launchd     Skip launchd plist install
  --skip-tests     Skip running tests/test_onboarding.sh
  --verbose        Verbose logging (does NOT echo settings.json contents)
  --merge-stop     Replace any existing Stop hook with ours instead of append
  -h, --help       Show this help

Exit codes:
  0   success
  10  missing dependency: claude
  11  missing dependency: jq / git / bash
  12  missing dependency: osascript / claude version too old
  20  --apply given without --vault
  21  --vault not a directory
  30  test failure
  40  jq merge failure
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --vault)        VAULT="${2:-}"; shift 2 ;;
    --vault=*)      VAULT="${1#*=}"; shift ;;
    --apply)        APPLY=1; DRY_RUN=0; shift ;;
    --dry-run)      APPLY=0; DRY_RUN=1; shift ;;
    --no-launchd)   NO_LAUNCHD=1; shift ;;
    --skip-tests)   SKIP_TESTS=1; shift ;;
    --verbose)      VERBOSE=1; shift ;;
    --merge-stop)   MERGE_STOP=1; shift ;;
    -h|--help)      usage; exit 0 ;;
    *) echo "unknown flag: $1" >&2; usage >&2; exit 2 ;;
  esac
done

# ---- logging -----------------------------------------------------------------
# NOTE: these helpers must NEVER receive settings.json contents as arguments.

log()  { printf '[install] %s\n' "$*" >&2; }
vlog() { [[ "$VERBOSE" -eq 1 ]] && printf '[install:v] %s\n' "$*" >&2 || true; }
warn() { printf '[install:WARN] %s\n' "$*" >&2; }
err()  { printf '[install:ERROR] %s\n' "$*" >&2; }

mode_banner() {
  if [[ "$APPLY" -eq 1 ]]; then
    log "mode=APPLY — changes will be made"
  else
    log "mode=DRY-RUN — no changes will be made (pass --apply to execute)"
  fi
}

# run() executes in apply mode, logs the command in dry-run.
run() {
  if [[ "$APPLY" -eq 1 ]]; then
    vlog "exec: $*"
    "$@"
  else
    log "would run: $*"
  fi
}

# ---- step 1: preflight -------------------------------------------------------

preflight() {
  log "step 1: preflight"

  command -v claude    >/dev/null 2>&1 || { err "missing: claude";    exit 10; }
  command -v jq        >/dev/null 2>&1 || { err "missing: jq";        exit 11; }
  command -v git       >/dev/null 2>&1 || { err "missing: git";       exit 11; }
  command -v bash      >/dev/null 2>&1 || { err "missing: bash";      exit 11; }
  command -v osascript >/dev/null 2>&1 || { err "missing: osascript"; exit 12; }

  local raw major minor
  raw="$(claude --version 2>/dev/null | awk '{print $NF}' | head -n1 | tr -d '[:space:]')"
  if [[ -z "$raw" ]]; then
    err "could not determine claude version"
    exit 12
  fi
  # strip leading v if present
  raw="${raw#v}"
  major="${raw%%.*}"
  local rest="${raw#*.}"
  minor="${rest%%.*}"
  if ! [[ "$major" =~ ^[0-9]+$ ]] || ! [[ "$minor" =~ ^[0-9]+$ ]]; then
    err "unparseable claude version: $raw"
    exit 12
  fi
  if (( major < 1 )) || { (( major == 1 )) && (( minor < 4 )); }; then
    err "claude >= 1.4.0 required (found: $raw)"
    exit 12
  fi
  vlog "claude version ok: $raw"
}

# ---- step 2/3: validate --vault ---------------------------------------------

validate_vault() {
  log "step 2/3: validate vault"
  if [[ "$APPLY" -eq 1 && -z "$VAULT" ]]; then
    err "--apply requires --vault PATH"
    exit 20
  fi
  if [[ -n "$VAULT" && ! -d "$VAULT" ]]; then
    err "--vault is not a directory: $VAULT"
    exit 21
  fi
  export VAULT
  vlog "vault=${VAULT:-<unset>}"
}

# ---- step 4: backup settings.json -------------------------------------------

backup_settings() {
  log "step 4: backup settings.json"
  if [[ ! -f "$SETTINGS_PATH" ]]; then
    vlog "no existing settings.json — skipping backup"
    return 0
  fi
  local ts dest
  ts="$(date +%Y-%m-%d-%H%M%S)"
  dest="$BACKUP_DIR_ROOT/$ts"
  run mkdir -p "$dest"
  run chmod 0700 "$dest"
  run cp -p "$SETTINGS_PATH" "$dest/settings.json"
  run chmod 0600 "$dest/settings.json"
  log "backup written to: $dest/settings.json (0600)"
}

# ---- step 5: jq-merge Stop hook ---------------------------------------------

merge_stop_hook() {
  log "step 5: merge Stop hook into settings.json"

  local our_hook_src="$REPO_ROOT/hooks/stop-hook.json"
  if [[ ! -f "$our_hook_src" ]]; then
    # Define a minimal default hook-overlay inline if repo ships none.
    local tmp_overlay
    tmp_overlay="$(mktemp -t mogging-stop-overlay.XXXXXX)"
    cat >"$tmp_overlay" <<'JSON'
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          { "type": "command",
            "command": "$REPO_ROOT/hooks/stop-hook.sh",
            "timeout": 60 }
        ]
      }
    ]
  }
}
JSON
    our_hook_src="$tmp_overlay"
    vlog "using default inline Stop overlay (no hooks/stop-hook.json in repo)"
  fi

  # Starting base: existing settings or {}
  local base="{}"
  if [[ -f "$SETTINGS_PATH" ]]; then
    base="$SETTINGS_PATH"
  fi

  # Detect existing Stop hook (count only — NEVER print contents)
  local existing_stop_count=0
  if [[ -f "$SETTINGS_PATH" ]]; then
    existing_stop_count="$(jq '(.hooks.Stop // []) | length' "$SETTINGS_PATH" 2>/dev/null || echo 0)"
  fi

  local merge_mode="append"
  if (( existing_stop_count > 0 )) && [[ "$MERGE_STOP" -eq 1 ]]; then
    merge_mode="replace"
  elif (( existing_stop_count > 0 )); then
    warn "existing Stop hook detected (count=$existing_stop_count); appending ours. Pass --merge-stop to replace."
  fi
  log "Stop-hook merge mode: $merge_mode"

  # Substitute $REPO_ROOT placeholder in overlay
  local overlay_resolved
  overlay_resolved="$(mktemp -t mogging-overlay.XXXXXX)"
  # shellcheck disable=SC2016
  sed -e "s|\$REPO_ROOT|$REPO_ROOT|g" "$our_hook_src" > "$overlay_resolved"

  if ! jq empty "$overlay_resolved" >/dev/null 2>&1; then
    err "overlay JSON is invalid; aborting merge"
    rm -f "$overlay_resolved"
    exit 40
  fi

  local merged
  merged="$(mktemp -t mogging-merged.XXXXXX)"
  if [[ "$merge_mode" == "replace" ]]; then
    # Deep overlay; .[1] wins for scalars/arrays at the same path.
    if ! jq -s '.[0] * .[1]' "$base" "$overlay_resolved" > "$merged" 2>/dev/null; then
      err "jq replace merge failed"
      rm -f "$overlay_resolved" "$merged"
      exit 40
    fi
  else
    # Append: concat .hooks.Stop arrays, keep rest of settings via deep merge,
    # then overwrite .hooks.Stop with the concatenation.
    if ! jq -s '
      ( .[0] * .[1] ) as $m
      | $m
      | .hooks = (.hooks // {})
      | .hooks.Stop = ((.[0].hooks.Stop // []) + (.[1].hooks.Stop // []))
    ' "$base" "$overlay_resolved" > "$merged" 2>/dev/null; then
      # Fallback: do it in two passes (older jq)
      if ! jq -s --slurpfile o <(cat "$overlay_resolved") '
        .[0] as $a
        | .[1] as $b
        | ($a * $b) * { hooks: (($a.hooks // {}) * ($b.hooks // {}) * { Stop: ((($a.hooks.Stop) // []) + (($b.hooks.Stop) // [])) }) }
      ' "$base" "$overlay_resolved" > "$merged" 2>/dev/null; then
        err "jq append merge failed"
        rm -f "$overlay_resolved" "$merged"
        exit 40
      fi
    fi
  fi

  if ! jq empty "$merged" >/dev/null 2>&1; then
    err "merged settings.json is invalid JSON"
    rm -f "$overlay_resolved" "$merged"
    exit 40
  fi

  if [[ "$APPLY" -eq 1 ]]; then
    run mkdir -p "$CLAUDE_HOME"
    run chmod 0700 "$CLAUDE_HOME"
    # Atomic write; NEVER cat contents to stdout.
    cp "$merged" "$SETTINGS_PATH.tmp.$$"
    chmod 0600 "$SETTINGS_PATH.tmp.$$"
    mv "$SETTINGS_PATH.tmp.$$" "$SETTINGS_PATH"
    log "settings.json updated (0600)"
  else
    log "would write merged settings.json to $SETTINGS_PATH (0600)"
  fi

  rm -f "$overlay_resolved" "$merged"
}

# ---- steps 6/7/8: symlink skills/commands/agents ----------------------------

symlink_dir() {
  local kind="$1"           # skills|commands|agents
  local src_root="$REPO_ROOT/$kind"
  local dest_root="$CLAUDE_HOME/$kind"
  log "step 6-8: symlink $kind"
  if [[ ! -d "$src_root" ]]; then
    vlog "no $kind dir at $src_root — skipping"
    return 0
  fi
  run mkdir -p "$dest_root"
  # iterate entries in src_root
  shopt -s nullglob
  local entry name dest
  for entry in "$src_root"/*; do
    [[ -d "$entry" || -f "$entry" ]] || continue
    name="$(basename "$entry")"
    dest="$dest_root/$name"
    if [[ -e "$dest" || -L "$dest" ]]; then
      run rm -rf "$dest"
    fi
    run ln -snf "$entry" "$dest"
    vlog "linked $kind/$name -> $entry"
  done
  shopt -u nullglob
}

# ---- step 9: Claude-Memory symlink in vault ---------------------------------

link_claude_memory() {
  log "step 9: Claude-Memory symlink in vault"
  if [[ -z "$VAULT" ]]; then
    vlog "vault not set — skipping Claude-Memory link"
    return 0
  fi
  if [[ ! -d "$CLAUDE_MEMORY_SRC" ]]; then
    warn "Claude memory source not found; skipping: $CLAUDE_MEMORY_SRC"
    return 0
  fi
  local dest="$VAULT/Claude-Memory"
  if [[ -e "$dest" || -L "$dest" ]]; then
    vlog "Claude-Memory link already present; refreshing"
    run rm -rf "$dest"
  fi
  run ln -s "$CLAUDE_MEMORY_SRC" "$dest"
}

# ---- step 10: launchd plists ------------------------------------------------

install_launchd() {
  if [[ "$NO_LAUNCHD" -eq 1 ]]; then
    log "step 10: launchd SKIPPED (--no-launchd)"
    return 0
  fi
  log "step 10: install launchd plists"

  local src_dir="$REPO_ROOT/scheduled/launchd"
  if [[ ! -d "$src_dir" ]]; then
    warn "no launchd source dir at $src_dir — skipping"
    return 0
  fi
  run mkdir -p "$LAUNCHAGENTS_DIR"

  shopt -s nullglob
  local plist name dest tmp
  for plist in "$src_dir"/*.plist; do
    name="$(basename "$plist")"
    dest="$LAUNCHAGENTS_DIR/$name"
    tmp="$(mktemp -t mogging-plist.XXXXXX)"

    # Placeholder substitution — uses | delimiter because paths contain /.
    # shellcheck disable=SC2016
    sed -e "s|\$REPO_ROOT|$REPO_ROOT|g" \
        -e "s|\$VAULT|${VAULT:-}|g" \
        "$plist" > "$tmp"

    if [[ "$APPLY" -eq 1 ]]; then
      # Unload first if present (ignore failure — may not be loaded).
      if [[ -f "$dest" ]]; then
        launchctl unload "$dest" 2>/dev/null || true
      fi
      cp "$tmp" "$dest"
      chmod 0644 "$dest"
      launchctl load "$dest"
      log "loaded: $name"
    else
      log "would install/load plist: $dest"
    fi
    rm -f "$tmp"
  done
  shopt -u nullglob
}

# ---- step 11: tests ----------------------------------------------------------

run_tests() {
  if [[ "$SKIP_TESTS" -eq 1 ]]; then
    log "step 11: tests SKIPPED (--skip-tests)"
    return 0
  fi
  local t="$REPO_ROOT/tests/test_onboarding.sh"
  if [[ ! -x "$t" && ! -f "$t" ]]; then
    warn "tests/test_onboarding.sh not found — skipping"
    return 0
  fi
  log "step 11a: test_onboarding.sh --dry-run"
  if ! bash "$t" --dry-run; then
    err "tests failed in dry-run"
    exit 30
  fi
  if [[ "$APPLY" -eq 1 ]]; then
    log "step 11b: test_onboarding.sh (real)"
    if ! bash "$t"; then
      err "tests failed in real mode"
      exit 30
    fi
  fi
}

# ---- step 12: doctor ---------------------------------------------------------

run_doctor() {
  log "step 12: doctor"
  local d="$REPO_ROOT/bin/doctor.sh"
  if [[ -x "$d" ]]; then
    if ! bash "$d"; then
      warn "doctor reported issues (non-fatal on install)"
    fi
  else
    vlog "bin/doctor.sh not found — skipping"
  fi
}

# ---- main --------------------------------------------------------------------

main() {
  mode_banner
  preflight
  validate_vault
  backup_settings
  merge_stop_hook
  symlink_dir "skills"
  symlink_dir "commands"
  symlink_dir "agents"
  link_claude_memory
  install_launchd
  run_tests
  run_doctor
  log "done."
}

main "$@"
