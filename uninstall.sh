#!/usr/bin/env bash
#
# 2ndBrain-mogging — uninstaller
#
# Reverses every install step:
#   - unloads + removes launchd plists from ~/Library/LaunchAgents
#   - removes our symlinks from ~/.claude/{skills,commands,agents}/
#   - removes only this checkout's hooks, preserving current settings (0600 perms)
#   - with --hard: also removes the Claude-Memory symlink inside the vault
#   - always retains backups for manual recovery
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

# shellcheck source=bin/lib/settings.sh
source "$REPO_ROOT/bin/lib/settings.sh"

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
  --keep-backups   Compatibility flag; backups are always retained
  --verbose        Extra logging
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --vault)
      [ "$#" -ge 2 ] && [ -n "${2:-}" ] || { echo "missing value for $1" >&2; exit 2; };
      VAULT="${2:-}"; shift 2 ;;
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
  local plist name dest escaped_root
  escaped_root="$(jq -nr --arg root "$REPO_ROOT" '$root | @html')"
  for plist in "$src_dir"/*.plist; do
    name="$(basename "$plist")"
    dest="$LAUNCHAGENTS_DIR/$name"
    if [[ -f "$dest" ]] && grep -qF "$escaped_root" "$dest"; then
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

# ---- 3. remove owned hooks from current settings -----------------------------

remove_settings_hooks() {
  validate_existing_settings "$SETTINGS_PATH" || return 1
  [[ -f "$SETTINGS_PATH" ]] || return 0
  command -v jq >/dev/null 2>&1 || { warn "jq required to safely remove hooks"; return 1; }
  local stop guard tmp saved intelligence='[]'
  if [[ -f "$CLAUDE_HOME/.mogging-intelligence" ]] && [[ "$(cat "$CLAUDE_HOME/.mogging-intelligence")" == "$REPO_ROOT" ]]; then
    intelligence="$(jq '[.hooks[][] | .hooks[].command]' "$REPO_ROOT/hooks/intelligence-hooks.json")"
  fi
  printf -v stop '%q' "$REPO_ROOT/hooks/stop-save.sh"
  printf -v guard '%q' "$REPO_ROOT/hooks/vault-guard.sh"
  tmp="$(mktemp "$CLAUDE_HOME/.mogging-settings.XXXXXX")"
  if ! jq --arg stop "$stop" --arg guard "$guard" --argjson intelligence "$intelligence" \
      --arg rawstop "$REPO_ROOT/hooks/stop-save.sh" --arg rawguard "$REPO_ROOT/hooks/vault-guard.sh" '
      if .hooks then
        .hooks |= with_entries(.value |= map(
          (.hooks | length) as $before
          | .hooks |= map(select(.command as $cmd | $cmd != $stop and $cmd != $guard and $cmd != $rawstop and $cmd != $rawguard and ($intelligence | index($cmd) | not)))
          | select($before == 0 or (.hooks | length > 0))))
      else . end
    ' "$SETTINGS_PATH" > "$tmp"; then
    rm -f "$tmp"
    warn "invalid settings; leaving them untouched"
    return 1
  fi
  if ! settings_json_valid "$tmp"; then
    rm -f "$tmp"
    warn "invalid settings result; leaving settings untouched"
    return 1
  fi
  mkdir -p "$BACKUP_DIR_ROOT"
  saved="$(mktemp -d "$BACKUP_DIR_ROOT/mogging-uninstall.XXXXXX")"
  cp -p "$SETTINGS_PATH" "$saved/settings.json"
  chmod 0600 "$saved/settings.json" "$tmp"
  mv "$tmp" "$SETTINGS_PATH"
  if [[ "$intelligence" != '[]' ]]; then rm -f "$CLAUDE_HOME/.mogging-intelligence"; fi
  log "removed owned hooks; current settings backed up at $saved"
}

# ---- 4. optional: remove Claude-Memory link in vault -------------------------

remove_claude_memory_link() {
  [[ "$HARD" -eq 1 ]] || { vlog "--hard not set; leaving Claude-Memory link"; return 0; }
  if [[ -z "$VAULT" ]]; then
    warn "--hard requires --vault PATH; skipping Claude-Memory removal"
    return 0
  fi
  local dest="$VAULT/Claude-Memory"
  local encoded="${VAULT//\//-}"
  if [[ -L "$dest" && "$(readlink "$dest")" == "$CLAUDE_HOME/projects/$encoded/memory" ]]; then
    rm -f "$dest"
    log "removed Claude-Memory symlink: $dest"
  else
    vlog "no Claude-Memory symlink at $dest"
  fi
}

# ---- 5. optional: purge backups ---------------------------------------------

purge_backups() {
  log "keeping backups for recovery (including --keep-backups=$KEEP_BACKUPS)"
}

remove_shell_shortcuts() {
  local name dest
  for name in cbrain cbraintg; do
    dest="$HOME/.local/bin/$name"
    if [[ -f "$dest" && ! -L "$dest" ]] && grep -qxF '# Managed by 2ndBrain-mogging.' "$dest"; then
      rm -f "$dest"
      log "removed $dest"
    fi
  done
  return 0
}

remove_vault_guard() {
  rm -f "${CLAUDE_HOME:?}/.mogging-guard"
}

remove_statusline_marker() {
  local marker="$CLAUDE_HOME/.mogging-vault"
  if [[ -f "$marker" ]]; then
    rm -f "$marker"
    log "removed $marker"
  else
    vlog "statusline marker not present"
  fi
}

# The third-party vault skill packs (step 10.75) are COPIED in, not symlinked,
# so unlink_kind() deliberately leaves them ("not a symlink; leaving") and they
# would otherwise orphan in ~/.claude/skills forever. Remove them here.
#
# Conservative on purpose: only delete a real directory. If the path is a
# symlink, some other tool (or a manual install) owns it — leave it alone.
remove_vault_skill_packs() {
  local packs=(obsidian-markdown obsidian-bases obsidian-cli json-canvas defuddle)
  local dest_root="$CLAUDE_HOME/skills"
  local s dest removed=0
  for s in "${packs[@]}"; do
    dest="$dest_root/$s"
    if [[ -L "$dest" ]]; then
      vlog "$dest is a symlink (not ours); leaving"
    elif [[ -d "$dest" && -f "$dest/.mogging-owned" ]] && [[ "$(cat "$dest/.mogging-owned")" == "$REPO_ROOT" ]]; then
      local saved
      mkdir -p "$BACKUP_DIR_ROOT"
      saved="$(mktemp -d "$BACKUP_DIR_ROOT/mogging-pack.XXXXXX")"
      mv "$dest" "$saved/$s"
      log "removed skill pack $s (preserved at $saved/$s)"
      removed=$((removed + 1))
    else
      vlog "skill pack $s not present"
    fi
  done
  [[ "$removed" -eq 0 ]] && vlog "no vault skill packs to remove"

  # The defuddle npm CLI is a SHARED global binary — the user may rely on it
  # outside this vault. Never yank it silently; just say it's still there.
  if command -v defuddle >/dev/null 2>&1; then
    log "note: the 'defuddle' CLI is still installed globally (shared tool)."
    log "      remove it yourself if you want: npm uninstall -g defuddle"
  fi
}

main() {
  log "starting uninstall"
  remove_settings_hooks
  uninstall_launchd
  unlink_kind "skills"
  unlink_kind "commands"
  unlink_kind "agents"
  remove_vault_skill_packs
  remove_vault_guard
  remove_claude_memory_link
  remove_statusline_marker
  remove_shell_shortcuts
  purge_backups
  log "done. Vault content untouched."
}

main "$@"
