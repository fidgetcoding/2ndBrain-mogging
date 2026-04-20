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
#              [--with-intelligence] [--symlink] [--no-obsidian-mcp]
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
# CLAUDE_MEMORY_SRC is derived from $VAULT at runtime in link_claude_memory().
# Claude Code encodes project paths as projects/<slashes→dashes>, so the
# memory dir for a vault at /foo/bar is $CLAUDE_HOME/projects/-foo-bar/memory.
CLAUDE_MEMORY_SRC=""

# ---- flags -------------------------------------------------------------------

VAULT=""
APPLY=0
# NOTE: dry-run is the default. All control flow keys off APPLY=0/1.
# There is deliberately NO `DRY_RUN` variable — a prior version carried
# one but nothing ever read it, which tripped shellcheck (SC2034) and
# made the state machine confusing. If you need a dry-run predicate,
# test `[[ "$APPLY" -eq 0 ]]`.
NO_LAUNCHD=0
NO_OBSIDIAN_MCP=0
SKIP_TESTS=0
VERBOSE=0
MERGE_STOP=0
WITH_INTELLIGENCE=0
USE_SYMLINK=0
NO_SEED_VAULT=0

usage() {
  cat <<'USAGE'
Usage: install.sh [options]

Options:
  --vault PATH         Absolute path to the Obsidian vault (required with --apply)
  --apply              Execute changes (default is dry-run)
  --dry-run            Simulate only (default)
  --no-launchd         Skip launchd plist install
  --no-obsidian-mcp    Skip obsidian-mcp registration (claude mcp add obsidian)
  --skip-tests         Skip running tests/test_onboarding.sh
  --verbose            Verbose logging (does NOT echo settings.json contents)
  --merge-stop         Replace any existing Stop hook with ours instead of append
  --no-seed-vault      Skip seeding the 7-folder vault layout from vault-template/.
                       Default is to copy missing folders (01-Conversations/,
                       02-Sources/, 03-Concepts/, 04-Index/, 05-Projects/,
                       06-Tasks/, Claude-Memory/ placeholder, CLAUDE.md,
                       AGENTS.md) into --vault. Existing files are never
                       overwritten — the seed is strictly additive.
  --with-intelligence  Install the self-learning tier (helpers/ + 5 hook types
                       merged into settings.json + seeded .claude-flow/data/).
                       OFF by default; existing users won't get surprise hooks.
  --symlink            With --with-intelligence: symlink helpers/ instead of
                       hardlinking (hardlink is default). Useful if the vault
                       lives on a different filesystem from this repo.
  -h, --help           Show this help

Exit codes:
  0   success
  10  missing dependency: claude
  11  missing dependency: jq / git / bash
  12  missing dependency: osascript / claude version too old
  20  --apply given without --vault
  21  --vault not a directory
  30  test failure
  40  jq merge failure
  41  CLAUDE.md patch extraction failure
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --vault)              VAULT="${2:-}"; shift 2 ;;
    --vault=*)            VAULT="${1#*=}"; shift ;;
    --apply)              APPLY=1; shift ;;
    --dry-run)            APPLY=0; shift ;;
    --no-launchd)         NO_LAUNCHD=1; shift ;;
    --no-obsidian-mcp)    NO_OBSIDIAN_MCP=1; shift ;;
    --skip-tests)         SKIP_TESTS=1; shift ;;
    --verbose)            VERBOSE=1; shift ;;
    --merge-stop)         MERGE_STOP=1; shift ;;
    --no-seed-vault)      NO_SEED_VAULT=1; shift ;;
    --with-intelligence)  WITH_INTELLIGENCE=1; shift ;;
    --symlink)            USE_SYMLINK=1; shift ;;
    -h|--help)            usage; exit 0 ;;
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
  raw="$(claude --version 2>/dev/null | head -n1 | awk '{print $1}' | tr -d '[:space:]')"
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

# ---- step 3.5: seed vault from vault-template/ ------------------------------
# For a freshly-created Obsidian vault (empty folder), copy the 7-folder layout
# + CLAUDE.md + AGENTS.md + Projects-Index + example projects out of
# vault-template/ into $VAULT. Strictly additive — existing files/folders are
# never overwritten. Skipped entirely with --no-seed-vault or if $VAULT is unset
# (the doctor-only / dry-run-only paths).

seed_vault_from_template() {
  log "step 3.5: seed vault from template"
  if [[ -z "$VAULT" ]]; then
    vlog "vault not set — skipping seed"
    return 0
  fi
  if [[ "$NO_SEED_VAULT" -eq 1 ]]; then
    log "--no-seed-vault set — skipping"
    return 0
  fi
  local src="$REPO_ROOT/vault-template"
  if [[ ! -d "$src" ]]; then
    warn "vault-template/ missing at $src — nothing to seed"
    return 0
  fi

  local copied=0 skipped=0
  # Top-level dirs (01-Conversations, 02-Sources, ...) — copy each if absent.
  # `cp -R` preserves nested empty dirs and .gitkeep files from the template,
  # which matters because git-clone drops truly-empty dirs but we want the
  # 7-folder layout to render even before any notes land in it.
  while IFS= read -r -d '' entry; do
    local rel="${entry#"$src"/}"
    # macOS litters vault-template with .DS_Store files during local editing;
    # skip them at the top level AND scrub any that rode along inside a dir.
    [[ "$rel" == ".DS_Store" ]] && continue
    [[ "$rel" == *"/.DS_Store" ]] && continue
    local dest="$VAULT/$rel"
    if [[ -e "$dest" ]]; then
      vlog "seed skip (exists): $rel"
      skipped=$((skipped + 1))
      continue
    fi
    # Use cp -R for directories (preserves nested empty dirs + .gitkeep);
    # install for files.
    if [[ -d "$entry" ]]; then
      run cp -R "$entry" "$dest"
      # Scrub any nested .DS_Store that rode along inside the copied tree.
      # Failure is non-fatal — the file simply may not exist.
      if [[ "$APPLY" -eq 1 && -d "$dest" ]]; then
        find "$dest" -name '.DS_Store' -type f -delete 2>/dev/null || true
      fi
    else
      run mkdir -p "$(dirname "$dest")"
      run cp "$entry" "$dest"
    fi
    vlog "seeded: $rel"
    copied=$((copied + 1))
  done < <(find "$src" -mindepth 1 -maxdepth 1 -print0)

  log "seeded $copied top-level entries from vault-template/ ($skipped already present)"
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
            "command": "$REPO_ROOT/hooks/stop-save.sh",
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
  local ours_already_present=0
  if [[ -f "$SETTINGS_PATH" ]]; then
    existing_stop_count="$(jq '(.hooks.Stop // []) | length' "$SETTINGS_PATH" 2>/dev/null || echo 0)"
    # Idempotency guard: detect if our own hook is already present by path fingerprint.
    if jq -e --arg p "2ndBrain-mogging/hooks/stop-" '
          (.hooks.Stop // []) | map(.hooks // []) | add | map(.command // "") | any(contains($p))
        ' "$SETTINGS_PATH" >/dev/null 2>&1; then
      ours_already_present=1
    fi
  fi

  local merge_mode="append"
  if (( ours_already_present == 1 )) && [[ "$MERGE_STOP" -ne 1 ]]; then
    log "our Stop hook already present in settings.json — skipping merge (pass --merge-stop to force replace)"
    return 0
  fi
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
  # Derive Claude Code's encoded project-memory dir from the vault path.
  # Claude encodes /foo/bar/baz as projects/-foo-bar-baz.
  local encoded="${VAULT//\//-}"
  CLAUDE_MEMORY_SRC="$CLAUDE_HOME/projects/${encoded}/memory"
  vlog "claude memory src: $CLAUDE_MEMORY_SRC"
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

# ---- step 9.5: apply CLAUDE.md patch to vault -------------------------------
#
# Reads docs/CLAUDE-MD-PATCH.md in this repo and applies the canonical post-
# mogging contract block to the vault's CLAUDE.md. Idempotent: re-running
# replaces the existing marker block, never duplicates. Also migrates legacy
# installs that used the pre-namespaced `<!-- mogging:* -->` markers by
# stripping the old block and writing a fresh `<!-- 2ndbrain-mogging:* -->`
# block in its place.
#
# Honors the 3-non-negotiables: backs up the existing CLAUDE.md to
# $VAULT/Claude-Memory/backups/YYYY-MM-DD-HHMMSS/ before any write.

apply_claude_md_patch() {
  log "step 9.5: apply CLAUDE.md patch"
  if [[ -z "$VAULT" ]]; then
    vlog "vault not set — skipping CLAUDE.md patch"
    return 0
  fi

  local patch_src="$REPO_ROOT/docs/CLAUDE-MD-PATCH.md"
  local vault_claude="$VAULT/CLAUDE.md"

  if [[ ! -f "$patch_src" ]]; then
    warn "patch source missing: $patch_src — skipping"
    return 0
  fi

  local patch_block working
  patch_block="$(mktemp -t mogging-patch-block.XXXXXX)"
  working="$(mktemp -t mogging-claude-working.XXXXXX)"

  # Extract block (markers inclusive) from patch source. The patch file wraps
  # the canonical block in a ```markdown fence; we only care about the lines
  # between the start and end markers.
  awk '
    /^<!-- 2ndbrain-mogging:start -->$/ { on = 1 }
    on { print }
    /^<!-- 2ndbrain-mogging:end -->$/ { on = 0 }
  ' "$patch_src" > "$patch_block"

  if [[ ! -s "$patch_block" ]]; then
    err "could not extract patch block from $patch_src (markers not found)"
    rm -f "$patch_block" "$working"
    exit 41
  fi

  if [[ -f "$vault_claude" ]]; then
    # Strip any existing namespaced OR legacy marker block (inclusive), then
    # drop trailing blank lines. Anything outside the markers is preserved
    # byte-for-byte. Backup is deferred until we know the content actually
    # changed (see content-diff guard below) so idempotent re-runs don't
    # pile up no-op backups.
    awk '
      /^<!-- 2ndbrain-mogging:start -->$/ { skip = 1; next }
      /^<!-- mogging:start -->$/          { skip = 1; next }
      skip && /^<!-- 2ndbrain-mogging:end -->$/ { skip = 0; next }
      skip && /^<!-- mogging:end -->$/          { skip = 0; next }
      skip { next }
      { lines[++n] = $0; if ($0 !~ /^[[:space:]]*$/) last = n }
      END { for (i = 1; i <= last; i++) print lines[i] }
    ' "$vault_claude" > "$working"
  else
    # No existing CLAUDE.md — create a minimal header so the patch has
    # something to anchor below.
    log "vault CLAUDE.md not found — creating with minimal header"
    printf '# CLAUDE.md\n\nThis file provides guidance to Claude Code when working in this vault.\n' > "$working"
  fi

  # Append a single blank line, then the canonical patch block.
  printf '\n' >> "$working"
  cat "$patch_block" >> "$working"

  # Idempotency guard: compare proposed content to existing file byte-for-byte.
  # Only touch the filesystem (backup + write) when content actually differs,
  # so repeat `--apply` runs don't bump mtime or accumulate dead backups.
  if [[ -f "$vault_claude" ]] && cmp -s "$working" "$vault_claude"; then
    log "CLAUDE.md already up to date — no write needed"
    rm -f "$patch_block" "$working"
    return 0
  fi

  if [[ "$APPLY" -eq 1 ]]; then
    # Backup per non-negotiable #1 (backup-before-mutation). Only runs when
    # an existing file is about to be replaced with different content.
    if [[ -f "$vault_claude" ]]; then
      local ts backup_dir
      ts="$(date +%Y-%m-%d-%H%M%S)"
      backup_dir="$VAULT/Claude-Memory/backups/$ts"
      mkdir -p "$backup_dir"
      cp -p "$vault_claude" "$backup_dir/CLAUDE.md.bak"
      vlog "backed up CLAUDE.md to $backup_dir/CLAUDE.md.bak"
    fi
    cp "$working" "$vault_claude"
    log "CLAUDE.md patched: $vault_claude"
  else
    log "would patch $vault_claude (block: $(wc -l < "$patch_block" | tr -d ' ') lines between markers)"
  fi

  rm -f "$patch_block" "$working"
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
    # $HOME must be substituted BEFORE $REPO_ROOT/$VAULT in case those are
    # themselves expressed relative to $HOME in future templates.
    # shellcheck disable=SC2016
    sed -e "s|\$HOME|$HOME|g" \
        -e "s|\$REPO_ROOT|$REPO_ROOT|g" \
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

# ---- step 10.5: self-learning intelligence tier (opt-in) --------------------
#
# Gated behind --with-intelligence. Three sub-steps:
#   (a) link_helpers()              — hardlink (or symlink with --symlink) every
#                                     file in repo/helpers/ into $VAULT/.claude/helpers/
#   (b) merge_intelligence_hooks()  — jq-deep-merge + concat-append the 5 hook
#                                     arrays from hooks/intelligence-hooks.json
#                                     into ~/.claude/settings.json. NEVER
#                                     replaces existing hooks (notably the
#                                     mogging Stop hook from hooks/stop-save.sh).
#   (c) seed_pattern_store()        — idempotent mkdir -p $VAULT/.claude-flow/data/
#                                     so the first session has a place to write.

link_helpers() {
  log "step 10.5a: link intelligence helpers into vault"
  if [[ -z "$VAULT" ]]; then
    vlog "vault not set — skipping helpers link"
    return 0
  fi

  local src_dir="$REPO_ROOT/helpers"
  local dest_dir="$VAULT/.claude/helpers"

  if [[ ! -d "$src_dir" ]]; then
    warn "helpers source missing at $src_dir — skipping"
    return 0
  fi

  run mkdir -p "$dest_dir"

  local mode="hardlink"
  [[ "$USE_SYMLINK" -eq 1 ]] && mode="symlink"
  log "helpers link mode: $mode"

  shopt -s nullglob
  local entry name dest
  for entry in "$src_dir"/*; do
    [[ -f "$entry" ]] || continue
    name="$(basename "$entry")"
    dest="$dest_dir/$name"

    # Remove any existing entry (file OR link) so link is idempotent.
    if [[ -e "$dest" || -L "$dest" ]]; then
      run rm -f "$dest"
    fi

    if [[ "$USE_SYMLINK" -eq 1 ]]; then
      run ln -s "$entry" "$dest"
    else
      # Try hardlink; fall back to symlink if cross-device (errno EXDEV).
      if [[ "$APPLY" -eq 1 ]]; then
        if ! ln "$entry" "$dest" 2>/dev/null; then
          vlog "hardlink failed (likely cross-device) — falling back to symlink: $name"
          ln -s "$entry" "$dest"
        fi
      else
        log "would hardlink: $entry -> $dest (falls back to symlink if cross-device)"
      fi
    fi
    vlog "linked helpers/$name"
  done
  shopt -u nullglob
}

merge_intelligence_hooks() {
  log "step 10.5b: merge intelligence hooks into settings.json"

  local overlay_src="$REPO_ROOT/hooks/intelligence-hooks.json"
  if [[ ! -f "$overlay_src" ]]; then
    warn "intelligence overlay missing at $overlay_src — skipping"
    return 0
  fi

  # Idempotency guard: check fingerprint "2ndBrain-mogging" hook-handler.cjs path
  # in any of the 5 hook arrays we touch. If present, assume ours is already merged.
  local ours_already_present=0
  if [[ -f "$SETTINGS_PATH" ]]; then
    if jq -e --arg p "helpers/hook-handler.cjs" '
          [ .hooks.PreToolUse, .hooks.PostToolUse, .hooks.UserPromptSubmit,
            .hooks.SessionStart, .hooks.SessionEnd ]
          | map(. // [])
          | map(.[]?.hooks // [])
          | flatten
          | map(.command // "")
          | any(contains($p))
        ' "$SETTINGS_PATH" >/dev/null 2>&1; then
      ours_already_present=1
    fi
  fi

  if (( ours_already_present == 1 )); then
    log "intelligence hooks already present in settings.json — skipping merge"
    return 0
  fi

  local base="{}"
  [[ -f "$SETTINGS_PATH" ]] && base="$SETTINGS_PATH"

  # The overlay has no placeholders to substitute (paths use ${CLAUDE_PROJECT_DIR:-.}).
  # Validate overlay JSON.
  if ! jq empty "$overlay_src" >/dev/null 2>&1; then
    err "intelligence overlay JSON is invalid; aborting merge"
    exit 40
  fi

  local merged
  merged="$(mktemp -t mogging-intel-merged.XXXXXX)"

  # Deep merge, then for each of the 5 hook arrays, concat existing + overlay.
  # This preserves the Stop hook and any other user hooks untouched.
  if ! jq -s '
    .[0] as $old
    | .[1] as $new
    | ($old * $new)
    | .hooks = (.hooks // {})
    | .hooks.PreToolUse       = (($old.hooks.PreToolUse       // []) + ($new.hooks.PreToolUse       // []))
    | .hooks.PostToolUse      = (($old.hooks.PostToolUse      // []) + ($new.hooks.PostToolUse      // []))
    | .hooks.UserPromptSubmit = (($old.hooks.UserPromptSubmit // []) + ($new.hooks.UserPromptSubmit // []))
    | .hooks.SessionStart     = (($old.hooks.SessionStart     // []) + ($new.hooks.SessionStart     // []))
    | .hooks.SessionEnd       = (($old.hooks.SessionEnd       // []) + ($new.hooks.SessionEnd       // []))
  ' "$base" "$overlay_src" > "$merged" 2>/dev/null; then
    err "jq intelligence merge failed"
    rm -f "$merged"
    exit 40
  fi

  if ! jq empty "$merged" >/dev/null 2>&1; then
    err "merged settings.json is invalid JSON after intelligence merge"
    rm -f "$merged"
    exit 40
  fi

  if [[ "$APPLY" -eq 1 ]]; then
    run mkdir -p "$CLAUDE_HOME"
    run chmod 0700 "$CLAUDE_HOME"
    cp "$merged" "$SETTINGS_PATH.tmp.$$"
    chmod 0600 "$SETTINGS_PATH.tmp.$$"
    mv "$SETTINGS_PATH.tmp.$$" "$SETTINGS_PATH"
    log "settings.json updated with intelligence hooks (0600)"
  else
    log "would write merged settings.json to $SETTINGS_PATH (0600)"
  fi

  rm -f "$merged"
}

seed_pattern_store() {
  log "step 10.5c: seed pattern store"
  if [[ -z "$VAULT" ]]; then
    vlog "vault not set — skipping pattern store seed"
    return 0
  fi
  run mkdir -p "$VAULT/.claude-flow/data"
  run mkdir -p "$VAULT/.claude-flow/learning"
  run mkdir -p "$VAULT/.claude-flow/metrics"
  run mkdir -p "$VAULT/.claude-flow/sessions"
}

install_intelligence() {
  if [[ "$WITH_INTELLIGENCE" -ne 1 ]]; then
    vlog "step 10.5: intelligence tier SKIPPED (pass --with-intelligence to enable)"
    return 0
  fi
  log "step 10.5: installing self-learning intelligence tier"
  link_helpers
  merge_intelligence_hooks
  seed_pattern_store
}

# ---- step 10.7: obsidian-mcp registration -----------------------------------
#
# Registers the `obsidian-mcp` server with Claude Code, pointed at $VAULT.
# Upstream: https://github.com/StevenStavrakis/obsidian-mcp (npm: obsidian-mcp).
# Idempotent — skips if already registered. Opt out with --no-obsidian-mcp.

install_obsidian_mcp() {
  if [[ "$NO_OBSIDIAN_MCP" -eq 1 ]]; then
    log "step 10.7: obsidian-mcp SKIPPED (--no-obsidian-mcp)"
    return 0
  fi
  log "step 10.7: register obsidian-mcp"

  if ! command -v claude >/dev/null 2>&1; then
    warn "claude CLI not found — skipping obsidian-mcp registration"
    return 0
  fi
  if [[ -z "${VAULT:-}" ]]; then
    vlog "vault not set — skipping obsidian-mcp"
    return 0
  fi

  # Already-registered fingerprint check (user-scope list).
  if claude mcp list 2>/dev/null | grep -qE '^obsidian[[:space:]]'; then
    log "obsidian-mcp already registered — skipping"
    return 0
  fi

  if [[ "$APPLY" -eq 1 ]]; then
    if claude mcp add --scope user obsidian -- npx -y obsidian-mcp "$VAULT" >/dev/null 2>&1; then
      log "obsidian-mcp registered (vault: $VAULT)"
    else
      warn "obsidian-mcp registration failed — run manually: claude mcp add --scope user obsidian -- npx -y obsidian-mcp \"$VAULT\""
    fi
  else
    log "would register obsidian-mcp: claude mcp add --scope user obsidian -- npx -y obsidian-mcp \"$VAULT\""
  fi
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
  # Tests require install.sh to actually run with --apply (writing files to
  # a throwaway vault). They cannot meaningfully execute in dry-run mode, so
  # step 11 is gated on APPLY. Pass --skip-tests to bypass even in apply mode.
  if [[ "$APPLY" -ne 1 ]]; then
    vlog "step 11: skipping tests in dry-run mode (run with --apply to execute)"
    return 0
  fi
  log "step 11: test_onboarding.sh"
  if ! bash "$t"; then
    err "tests failed"
    exit 30
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
#
# Install pipeline — every step in order, one line each. Keep this in sync
# with README's "On --apply" summary so the install surface stays auditable
# without spelunking the shell functions.
#
#   step 1    preflight                  claude + jq/git/bash + osascript + version gate
#   step 2/3  validate_vault             --apply requires --vault; must be a directory
#   step 3.5  seed_vault_from_template   additive copy of 7-folder layout + template files
#   step 4    backup_settings            timestamped ~/.claude/.backups/<ts>/settings.json
#   step 5    merge_stop_hook            jq-merge Stop hook (append | replace | skip-if-present)
#   step 6    symlink_dir "skills"       ~/.claude/skills/<name> -> repo/skills/<name>
#   step 7    symlink_dir "commands"     ~/.claude/commands/<name> -> repo/commands/<name>
#   step 8    symlink_dir "agents"       ~/.claude/agents/<name> -> repo/agents/<name>
#   step 9    link_claude_memory         $VAULT/Claude-Memory -> ~/.claude/projects/<enc>/memory
#   step 9.5  apply_claude_md_patch      idempotent CLAUDE.md patch (content-diff; no-op if same)
#   step 10   install_launchd            scheduled/launchd/*.plist -> ~/Library/LaunchAgents
#   step 10.5 install_intelligence       (opt-in --with-intelligence) helpers + hooks + pattern store
#   step 10.7 install_obsidian_mcp       claude mcp add obsidian → vault; opt out w/ --no-obsidian-mcp
#   step 11   run_tests                  tests/test_onboarding.sh (gated on --apply)
#   step 12   run_doctor                 bin/doctor.sh (non-fatal — issues warn only)
#

main() {
  mode_banner
  preflight
  validate_vault
  seed_vault_from_template
  backup_settings
  merge_stop_hook
  symlink_dir "skills"
  symlink_dir "commands"
  symlink_dir "agents"
  link_claude_memory
  apply_claude_md_patch
  install_launchd
  install_intelligence
  install_obsidian_mcp
  run_tests
  run_doctor
  log "done."
}

main "$@"
