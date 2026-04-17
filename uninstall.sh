#!/usr/bin/env bash
#
# 2ndBrain-mogging — uninstaller
#
# Reverses every install step:
#   - unloads + removes launchd plists from ~/Library/LaunchAgents
#   - removes our symlinks from ~/.claude/{skills,commands,agents}/
#   - restores the most recent settings.json backup (0600 perms)
#   - with --hard: also removes the Claude-Memory symlink inside the vault
#   - with --keep-backups: leaves ~/.claude/.backups/ alone
#
# Vault content (notes, files) is NEVER touched.
#

set -euo pipefail
IFS=$'\n\t'

SCRIPT_PATH="${BASH_SOURCE[0]}"
while [[ -L "$SCRIPT_PATH" ]]; do
  SCRIPT_DIR="$(cd -P "$(dirname "$SCRIPT_PATH")" >/dev/null 2>&1 && pwd)"
  SCRIPT_PATH="$(readlink "$SCRIPT_PATH")"
  [[ "$SCRIPT_PATH" != /* ]] && SCRIPT_PATH="$SCRIPT_DIR/$SCRIPT_PATH"
done
REPO_ROOT="$(cd -P "$(dirname "$SCRIPT_PATH")" >/dev/null 2>&1 && pwd)"

CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
BACKUP_DIR_ROOT="$CLAUDE_HOME/.backups"
SETTINGS_PATH="$CLAUDE_HOME/settings.json"
LAUNCHAGENTS_DIR="$HOME/Library/LaunchAgents"

HARD=0
KEEP_BACKUPS=0
VAULT=""
VERBOSE=0

usage() {
  cat <<'USAGE'
Usage: uninstall.sh [--vault PATH] [--hard] [--keep-backups] [--verbose]

Options:
  --vault PATH     Path to vault (required with --hard)
  --hard           Also remove the Claude-Memory symlink inside the vault
  --keep-backups   Do not delete ~/.claude/.backups (still restores)
  --verbose        Extra logging
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --vault)        VAULT="${2:-}"; shift 2 ;;
    --vault=*)      VAULT="${1#*=}"; shift ;;
    --hard)         HARD=1; shift ;;
    --keep-backups) KEEP_BACKUPS=1; shift ;;
    --verbose)      VERBOSE=1; shift ;;
    -h|--help)      usage; exit 0 ;;
    *) echo "unknown flag: $1" >&2; usage >&2; exit 2 ;;
  esac
done

log()  { printf '[uninstall] %s\n' "$*" >&2; }
vlog() { [[ "$VERBOSE" -eq 1 ]] && printf '[uninstall:v] %s\n' "$*" >&2 || true; }
warn() { printf '[uninstall:WARN] %s\n' "$*" >&2; }

# ---- 1. unload + remove launchd plists ---------------------------------------

uninstall_launchd() {
  log "unload + remove launchd plists"
  local src_dir="$REPO_ROOT/scheduled/launchd"
  [[ -d "$src_dir" ]] || { vlog "no plists to remove"; return 0; }
  shopt -s nullglob
  local plist name dest
  for plist in "$src_dir"/*.plist; do
    name="$(basename "$plist")"
    dest="$LAUNCHAGENTS_DIR/$name"
    if [[ -f "$dest" ]]; then
      launchctl unload "$dest" 2>/dev/null || true
      rm -f "$dest"
      log "removed $dest"
    else
      vlog "not installed: $dest"
    fi
  done
  shopt -u nullglob
}

# ---- 2. remove symlinks from ~/.claude/{skills,commands,agents}/ -------------

unlink_kind() {
  local kind="$1"
  local src_root="$REPO_ROOT/$kind"
  local dest_root="$CLAUDE_HOME/$kind"
  [[ -d "$src_root" && -d "$dest_root" ]] || { vlog "nothing to unlink for $kind"; return 0; }
  shopt -s nullglob
  local entry name dest
  for entry in "$src_root"/*; do
    name="$(basename "$entry")"
    dest="$dest_root/$name"
    if [[ -L "$dest" ]]; then
      local target
      target="$(readlink "$dest" 2>/dev/null || true)"
      if [[ "$target" == "$entry" ]]; then
        rm -f "$dest"
        log "unlinked $kind/$name"
      else
        vlog "$dest points elsewhere ($target); leaving"
      fi
    else
      vlog "$dest is not a symlink; leaving"
    fi
  done
  shopt -u nullglob
}

# ---- 3. restore most-recent settings.json backup -----------------------------

restore_settings() {
  log "restore most-recent settings.json backup"
  if [[ ! -d "$BACKUP_DIR_ROOT" ]]; then
    vlog "no backup root; nothing to restore"
    return 0
  fi
  local latest
  # Pick the lexicographically greatest subdir with a settings.json inside.
  latest="$(find "$BACKUP_DIR_ROOT" -mindepth 1 -maxdepth 1 -type d -name '20*' \
            -exec test -f {}/settings.json \; -print 2>/dev/null \
            | sort -r | head -n1)"
  if [[ -z "$latest" ]]; then
    warn "no viable settings.json backup found"
    return 0
  fi
  cp "$latest/settings.json" "$SETTINGS_PATH.tmp.$$"
  chmod 0600 "$SETTINGS_PATH.tmp.$$"
  mv "$SETTINGS_PATH.tmp.$$" "$SETTINGS_PATH"
  log "restored settings.json from $latest"
}

# ---- 4. optional: remove Claude-Memory link in vault -------------------------

remove_claude_memory_link() {
  [[ "$HARD" -eq 1 ]] || { vlog "--hard not set; leaving Claude-Memory link"; return 0; }
  if [[ -z "$VAULT" ]]; then
    warn "--hard requires --vault PATH; skipping Claude-Memory removal"
    return 0
  fi
  local dest="$VAULT/Claude-Memory"
  if [[ -L "$dest" ]]; then
    rm -f "$dest"
    log "removed Claude-Memory symlink: $dest"
  else
    vlog "no Claude-Memory symlink at $dest"
  fi
}

# ---- 5. optional: purge backups ---------------------------------------------

purge_backups() {
  if [[ "$KEEP_BACKUPS" -eq 1 ]]; then
    log "keeping backups (--keep-backups)"
    return 0
  fi
  if [[ -d "$BACKUP_DIR_ROOT" ]]; then
    rm -rf "$BACKUP_DIR_ROOT"
    log "purged $BACKUP_DIR_ROOT"
  fi
}

main() {
  log "starting uninstall"
  uninstall_launchd
  unlink_kind "skills"
  unlink_kind "commands"
  unlink_kind "agents"
  restore_settings
  remove_claude_memory_link
  purge_backups
  log "done. Vault content untouched."
}

main "$@"
