#!/usr/bin/env bash
# tests/test_guard_install.sh
# install.sh --with-guard wires the vault guard in, and only then. Temp home and
# temp vault throughout, so nothing here reaches a real ~/.claude.

set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/.." && pwd)"
# shellcheck source=./lib/assertions.sh
source "$HERE/lib/assertions.sh"

assert_reset "test_guard_install"

TMPROOT="$(mktemp -d -t 2brain-guard-XXXXXX)"
cleanup() {
  if [[ -n "${TMPROOT:-}" && ( "$TMPROOT" == /tmp/* || "$TMPROOT" == /var/folders/* ) ]]; then
    rm -rf "${TMPROOT:?}"
  fi
}
trap cleanup EXIT

export HOME="$TMPROOT/home"
export CLAUDE_HOME="$HOME/.claude"
mkdir -p "$CLAUDE_HOME"
VAULT="$HOME/vault"
mkdir -p "$VAULT"
SETTINGS="$CLAUDE_HOME/settings.json"
MARKER="$CLAUDE_HOME/.mogging-guard"

# Same isolation flags as test_onboarding.sh, plus no skill packs so it stays offline.
run_install() {
  VAULT_DIR="$VAULT" bash "$REPO_ROOT/install.sh" --vault "$VAULT" --apply \
    --no-launchd --no-obsidian-app --no-obsidian-mcp --no-statusline-brain \
    --no-shell-shortcuts --no-skill-packs --skip-tests "$@" >/dev/null 2>&1
}
guard_count() {
  jq '[(.hooks.PreToolUse // [])[].hooks[]?.command // "" | select(contains("hooks/vault-guard.sh"))] | length' "$SETTINGS"
}

# Dry run writes nothing.
bash "$REPO_ROOT/install.sh" --vault "$VAULT" --with-guard --no-launchd --no-obsidian-app \
  --no-obsidian-mcp --no-statusline-brain --no-shell-shortcuts --no-skill-packs --skip-tests >/dev/null 2>&1
if [[ -e "$MARKER" ]]; then _fail "dry run wrote the marker"; else _pass "dry run writes no marker"; fi

# Default install: off.
run_install
assert_eq "$?" "0" "default install exits 0"
assert_json_valid "$SETTINGS" "settings.json valid after default install"
assert_eq "$(guard_count)" "0" "default install adds no guard hook"
if [[ -e "$MARKER" ]]; then _fail "default install wrote the marker"; else _pass "default install writes no marker"; fi

# A hook of the user's own, which the merge must keep.
jq '.hooks.PreToolUse = ((.hooks.PreToolUse // []) + [{matcher:"Bash",hooks:[{type:"command",command:"echo user-pre"}]}])' \
  "$SETTINGS" > "$SETTINGS.new" && mv "$SETTINGS.new" "$SETTINGS"

# Opt in.
run_install --with-guard
assert_eq "$?" "0" "--with-guard install exits 0"
assert_json_valid "$SETTINGS" "settings.json valid after --with-guard"
assert_eq "$(guard_count)" "1" "--with-guard adds the hook"
assert_contains "$SETTINGS" "echo user-pre" "user's own PreToolUse hook kept"
assert_contains "$SETTINGS" "hooks/stop-save.sh" "Stop hook kept"
assert_file "$MARKER" "--with-guard writes the marker"
assert_eq "$(cd -P "$(head -n1 "$MARKER")" && pwd -P)" "$(cd -P "$VAULT" && pwd -P)" "the marker holds the vault path"

# The hook, run the way settings.json says to run it, against a real task file.
mkdir -p "$VAULT/05-Tasks"
cp "$HERE/fixtures/tasks/before.md" "$VAULT/05-Tasks/TASKS-SAMPLE.md"
CMD="$(jq -r '[(.hooks.PreToolUse // [])[].hooks[]?.command // "" | select(contains("hooks/vault-guard.sh"))][0]' "$SETTINGS")"
jq -n --arg f "$VAULT/05-Tasks/TASKS-SAMPLE.md" --rawfile c "$HERE/fixtures/tasks/after-rewritten.md" \
  '{tool_name:"Write",tool_input:{file_path:$f,content:$c}}' | "$CMD" 2>/dev/null
assert_eq "$?" "2" "the installed hook blocks a rewritten ID"

# Re-install is idempotent.
run_install --with-guard
assert_eq "$(guard_count)" "1" "re-install does not duplicate the hook"

# Uninstall takes it out, even though the newest backup holds it.
bash "$REPO_ROOT/uninstall.sh" --vault "$VAULT" >/dev/null 2>&1
assert_eq "$?" "0" "uninstall exits 0"
if [[ -e "$MARKER" ]]; then _fail "uninstall left the marker"; else _pass "uninstall removes the marker"; fi
if [[ -f "$SETTINGS" ]]; then
  assert_json_valid "$SETTINGS" "settings.json valid after uninstall"
  assert_eq "$(guard_count)" "0" "uninstall removes the hook"
else
  _pass "uninstall left no settings.json to hold the hook"
fi

assert_report
