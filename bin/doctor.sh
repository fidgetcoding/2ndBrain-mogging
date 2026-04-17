#!/usr/bin/env bash
#
# 2ndBrain-mogging — doctor
#
# Sanity-check that the install is healthy:
#   - every symlink under ~/.claude/{skills,commands,agents}/ resolves
#   - every plist shipped in scheduled/launchd/ is installed and loaded
#   - the plugin shows up in `claude plugin list`
#
# Exit codes:
#   0 = all green
#   1 = one or more issues detected
#

set -euo pipefail
IFS=$'\n\t'

SCRIPT_PATH="${BASH_SOURCE[0]}"
while [[ -L "$SCRIPT_PATH" ]]; do
  SCRIPT_DIR="$(cd -P "$(dirname "$SCRIPT_PATH")" >/dev/null 2>&1 && pwd)"
  SCRIPT_PATH="$(readlink "$SCRIPT_PATH")"
  [[ "$SCRIPT_PATH" != /* ]] && SCRIPT_PATH="$SCRIPT_DIR/$SCRIPT_PATH"
done
BIN_DIR="$(cd -P "$(dirname "$SCRIPT_PATH")" >/dev/null 2>&1 && pwd)"
REPO_ROOT="$(cd -P "$BIN_DIR/.." >/dev/null 2>&1 && pwd)"

CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
LAUNCHAGENTS_DIR="$HOME/Library/LaunchAgents"

FAIL=0
pass() { printf '[doctor:ok]   %s\n' "$*"; }
fail() { printf '[doctor:FAIL] %s\n' "$*" >&2; FAIL=1; }
info() { printf '[doctor:info] %s\n' "$*"; }

# ---- symlink checks ---------------------------------------------------------

check_symlinks_for_kind() {
  local kind="$1"
  local src_root="$REPO_ROOT/$kind"
  local dest_root="$CLAUDE_HOME/$kind"
  info "checking $kind symlinks"
  [[ -d "$src_root" ]] || { info "no $kind in repo; skipping"; return 0; }
  shopt -s nullglob
  local entry name dest target
  for entry in "$src_root"/*; do
    name="$(basename "$entry")"
    dest="$dest_root/$name"
    if [[ ! -L "$dest" ]]; then
      fail "not a symlink: $dest"
      continue
    fi
    target="$(readlink "$dest" 2>/dev/null || true)"
    if [[ "$target" != "$entry" ]]; then
      fail "$dest -> $target (expected $entry)"
      continue
    fi
    if [[ ! -e "$dest" ]]; then
      fail "dangling symlink: $dest"
      continue
    fi
    pass "$kind/$name"
  done
  shopt -u nullglob
}

# ---- launchd checks ---------------------------------------------------------

check_launchd() {
  info "checking launchd jobs"
  local src_dir="$REPO_ROOT/scheduled/launchd"
  [[ -d "$src_dir" ]] || { info "no launchd sources; skipping"; return 0; }
  shopt -s nullglob
  local plist name dest label
  for plist in "$src_dir"/*.plist; do
    name="$(basename "$plist")"
    dest="$LAUNCHAGENTS_DIR/$name"
    if [[ ! -f "$dest" ]]; then
      fail "plist not installed: $dest"
      continue
    fi
    # extract label without a plist-only tool — grep the literal <string>
    label="$(awk '/<key>Label<\/key>/{getline; sub(/.*<string>/,""); sub(/<\/string>.*/,""); print; exit}' "$dest")"
    if [[ -z "$label" ]]; then
      fail "could not determine Label in $dest"
      continue
    fi
    if launchctl list 2>/dev/null | awk '{print $3}' | grep -qx "$label"; then
      pass "launchd loaded: $label"
    else
      fail "launchd not loaded: $label (file present at $dest)"
    fi
  done
  shopt -u nullglob
}

# ---- plugin registration -----------------------------------------------------

check_plugin_registered() {
  info "checking plugin registration"
  if ! command -v claude >/dev/null 2>&1; then
    fail "claude CLI not on PATH"
    return
  fi
  # read plugin name from .claude-plugin/plugin.json if present
  local plugin_name=""
  if [[ -f "$REPO_ROOT/.claude-plugin/plugin.json" ]] && command -v jq >/dev/null 2>&1; then
    plugin_name="$(jq -r '.name // empty' "$REPO_ROOT/.claude-plugin/plugin.json" 2>/dev/null || true)"
  fi
  if [[ -z "$plugin_name" ]]; then
    plugin_name="2ndbrain-mogging"
  fi
  if claude plugin list 2>/dev/null | grep -q "$plugin_name"; then
    pass "plugin registered: $plugin_name"
  else
    fail "plugin not registered with 'claude plugin list': $plugin_name"
  fi
}

main() {
  check_symlinks_for_kind "skills"
  check_symlinks_for_kind "commands"
  check_symlinks_for_kind "agents"
  check_launchd
  check_plugin_registered
  if [[ "$FAIL" -eq 0 ]]; then
    printf '[doctor] all checks passed\n'
    exit 0
  fi
  printf '[doctor] one or more checks failed\n' >&2
  exit 1
}

main "$@"
