#!/usr/bin/env bash
# tests/test_uuid_preservation.sh
# Task 🆔 IDs must survive every edit byte-for-byte. Runs the real gate (bin/save)
# and the optional PreToolUse hook (hooks/vault-guard.sh) against the fixtures in
# tests/fixtures/tasks/.
#
# This proves the gate. It can't prove what a model does when the hook isn't
# installed, because /save itself is instructions to a model.

set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/.." && pwd)"
# shellcheck source=./lib/assertions.sh
source "$HERE/lib/assertions.sh"

assert_reset "test_uuid_preservation"

TMPROOT="$(mktemp -d -t 2brain-uuid-XXXXXX)"
cleanup() {
  if [[ -n "${TMPROOT:-}" && ( "$TMPROOT" == /tmp/* || "$TMPROOT" == /var/folders/* ) ]]; then
    rm -rf "${TMPROOT:?}"
  fi
}
trap cleanup EXIT

VAULT="$TMPROOT/vault"
cp -R "$HERE/fixtures/sample-vault/." "$VAULT/"
export HOME="$TMPROOT/home"
unset CLAUDE_HOME
mkdir -p "$HOME/.claude"

SAVE_CMD="$REPO_ROOT/bin/save"
GUARD="$REPO_ROOT/hooks/vault-guard.sh"
FIX="$HERE/fixtures/tasks"
assert_file "$SAVE_CMD" "bin/save exists"
assert_file "$GUARD" "hooks/vault-guard.sh exists"

UUID1="m-0a1b2c3d"
UUID2="m-4e5f6a7b"
UUID3="m-8c9d0e1f"
UUID_LEGACY="3f2b8a60-7c1e-4f8e-9a3b-5d6e7f8a9b0c"
TASKS_FILE="$VAULT/05-Tasks/TASKS-SAMPLE.md"
cp "$FIX/before.md" "$TASKS_FILE"

expect_pass() {
  local after="$1" label="$2"
  if "$SAVE_CMD" check-tasks --before "$FIX/before.md" --after "$FIX/$after" >/dev/null 2>&1; then
    _pass "$label"
  else
    _fail "$label (gate rejected it)"
  fi
}

# Exit 1 and the reason on stdout. Exit 1 alone isn't enough: a crash can exit 1 too.
expect_reject() {
  local after="$1" reason="$2" label="$3" out rc
  out="$("$SAVE_CMD" check-tasks --before "$FIX/before.md" --after "$FIX/$after" 2>/dev/null)"
  rc=$?
  assert_eq "$rc" "1" "$label: exits 1"
  if printf '%s' "$out" | grep -q "$reason"; then
    _pass "$label: says $reason"
  else
    _fail "$label: expected '$reason' in: $out"
  fi
}

# ---------------------------------------------------------------------------
# The rule, case by case.
# ---------------------------------------------------------------------------
expect_pass   before.md                   "no change passes"
expect_pass   after-legit-edit.md         "text, date and done-mark edits pass"
expect_pass   after-new-task-no-id.md     "a new task with no ID passes (W1 mints it)"
expect_reject after-rewritten.md          "rewritten"   "rewritten ID"
expect_reject after-dropped.md            "dropped"     "dropped ID"
expect_reject after-removed.md            "removed"     "removed task"
expect_reject after-duplicated.md         "duplicated"  "duplicated ID"
expect_reject after-swapped.md            "swapped"     "IDs swapped between tasks"
expect_reject after-self-minted-uuidv4.md "self-minted" "self-minted UUIDv4"
expect_reject after-self-minted-short.md  "self-minted" "self-minted m-XXXXXXXX"
expect_reject after-legacy-rewritten.md   "rewritten"   "legacy UUIDv4 rewritten to the new format"

# ---------------------------------------------------------------------------
# write-tasks, against a real file in a temp vault.
# ---------------------------------------------------------------------------
BEFORE_MD5="$(md5_of "$TASKS_FILE")"
BEFORE_COUNT="$(grep -c '🆔' "$TASKS_FILE" | tr -d ' ')"

# A no-op write through the gate.
cp "$TASKS_FILE" "$TMPROOT/same.md"
VAULT_DIR="$VAULT" "$SAVE_CMD" write-tasks --target 05-Tasks/TASKS-SAMPLE.md --from "$TMPROOT/same.md" --yes >/dev/null 2>&1

assert_file "$TASKS_FILE" "tasks file still exists after /save"

assert_contains "$TASKS_FILE" "🆔 ${UUID1}" "UUID ${UUID1} preserved byte-for-byte"
assert_contains "$TASKS_FILE" "🆔 ${UUID2}" "UUID ${UUID2} preserved byte-for-byte"
assert_contains "$TASKS_FILE" "🆔 ${UUID3}" "UUID ${UUID3} preserved byte-for-byte"
assert_contains "$TASKS_FILE" "🆔 ${UUID_LEGACY}" "legacy UUID preserved byte-for-byte"

AFTER_COUNT="$(grep -c '🆔' "$TASKS_FILE" | tr -d ' ')"
assert_eq "$AFTER_COUNT" "$BEFORE_COUNT" "UUID count unchanged ($BEFORE_COUNT)"

# No rogue UUIDs injected. We define "UUID" here loosely as '🆔 <token>' where
# token is not one of the ones we planted, nor the empty string.
ROGUE=0
while IFS= read -r line; do
  tok="$(echo "$line" | sed -n 's/.*🆔[[:space:]]*\([A-Za-z0-9_-]\{1,\}\).*/\1/p')"
  [[ -z "$tok" ]] && continue
  case "$tok" in
    "$UUID1"|"$UUID2"|"$UUID3"|"$UUID_LEGACY") ;;
    *) ROGUE=$((ROGUE + 1)) ;;
  esac
done < "$TASKS_FILE"
assert_eq "$ROGUE" "0" "no rogue UUIDs injected by /save"

assert_eq "$(md5_of "$TASKS_FILE")" "$BEFORE_MD5" "tasks file byte-identical after a no-op write"

# A broken edit changes nothing on disk.
VAULT_DIR="$VAULT" "$SAVE_CMD" write-tasks --target 05-Tasks/TASKS-SAMPLE.md --from "$FIX/after-rewritten.md" --yes >/dev/null 2>&1
assert_eq "$?" "1" "write-tasks refuses a rewritten ID"
assert_eq "$(md5_of "$TASKS_FILE")" "$BEFORE_MD5" "tasks file untouched after the refusal"

# Declining the prompt changes nothing either.
printf 'n\n' | VAULT_DIR="$VAULT" "$SAVE_CMD" write-tasks --target 05-Tasks/TASKS-SAMPLE.md --from "$FIX/after-legit-edit.md" >/dev/null 2>&1
assert_eq "$(md5_of "$TASKS_FILE")" "$BEFORE_MD5" "tasks file untouched after answering n"

# A good edit lands, keeps the IDs, and leaves a backup behind.
VAULT_DIR="$VAULT" "$SAVE_CMD" write-tasks --target 05-Tasks/TASKS-SAMPLE.md --from "$FIX/after-legit-edit.md" --yes >/dev/null 2>&1
assert_eq "$?" "0" "write-tasks accepts a legitimate edit"
assert_contains "$TASKS_FILE" "with the receipts" "the edit landed"
assert_contains "$TASKS_FILE" "🆔 ${UUID2}" "edited task kept its ID"
BACKUPS="$(find "$VAULT/Claude-Memory/backups" -type f -name '*TASKS-SAMPLE.md.bak' 2>/dev/null | wc -l | tr -d ' ')"
assert_eq "$BACKUPS" "1" "a backup was taken before overwriting"

# write-tasks is only for tasks.
VAULT_DIR="$VAULT" "$SAVE_CMD" write-tasks --target 02-Sources/not-tasks.md --from "$FIX/before.md" --yes >/dev/null 2>&1
assert_eq "$?" "3" "write-tasks refuses a path outside 05-Tasks/"
if [[ -e "$VAULT/02-Sources/not-tasks.md" ]]; then _fail "file written outside 05-Tasks/"; else _pass "nothing written outside 05-Tasks/"; fi

# ---------------------------------------------------------------------------
# The hook, with the same JSON Claude Code feeds it on stdin.
# ---------------------------------------------------------------------------
cp "$FIX/before.md" "$TASKS_FILE"

hook() { "$GUARD" 2>"$TMPROOT/hook.err"; }

write_json() { jq -n --arg f "$1" --rawfile c "$2" '{tool_name:"Write",tool_input:{file_path:$f,content:$c}}'; }
edit_json() {
  jq -n --arg f "$1" --arg o "$2" --arg n "$3" --argjson a "${4:-false}" \
    '{tool_name:"Edit",tool_input:{file_path:$f,old_string:$o,new_string:$n,replace_all:$a}}'
}

# Off unless installed: no marker, no enforcement.
write_json "$TASKS_FILE" "$FIX/after-rewritten.md" | hook
assert_eq "$?" "0" "hook does nothing without the opt-in marker"

printf '%s\n' "$VAULT" > "$HOME/.claude/.mogging-guard"

write_json "$TASKS_FILE" "$FIX/after-legit-edit.md" | hook
assert_eq "$?" "0" "hook allows a Write that keeps the IDs"

write_json "$TASKS_FILE" "$FIX/after-rewritten.md" | hook
assert_eq "$?" "2" "hook blocks a Write that rewrites an ID"
assert_contains "$TMPROOT/hook.err" "rewritten" "the block tells Claude why"

write_json "$TASKS_FILE" "$FIX/after-new-task-no-id.md" | hook
assert_eq "$?" "0" "hook allows a new task with no ID"

write_json "$TASKS_FILE" "$FIX/after-self-minted-uuidv4.md" | hook
assert_eq "$?" "2" "hook blocks a self-minted UUIDv4"

edit_json "$TASKS_FILE" "🆔 $UUID1" "🆔 m-11111111" | hook
assert_eq "$?" "2" "hook blocks an Edit that rewrites an ID"

edit_json "$TASKS_FILE" " 🆔 $UUID3" "" | hook
assert_eq "$?" "2" "hook blocks an Edit that drops an ID"

edit_json "$TASKS_FILE" "renew the library card" "renew the library card online" | hook
assert_eq "$?" "0" "hook allows an Edit to the task text"

edit_json "$TASKS_FILE" "- [ ] book the dentist" "- [x] book the dentist" | hook
assert_eq "$?" "0" "hook allows marking a task done"

edit_json "$TASKS_FILE" "m-" "z-" true | hook
assert_eq "$?" "2" "hook blocks a replace_all that rewrites every ID"

# old_string isn't in the file, so the tool will change nothing. Not the hook's call.
edit_json "$TASKS_FILE" "this text is not in the file" "🆔 m-22222222" | hook
assert_eq "$?" "0" "an Edit whose old_string isn't there isn't blocked"

jq -n --arg f "$TASKS_FILE" --arg i "🆔 $UUID2" '{tool_name:"MultiEdit",tool_input:{file_path:$f,edits:[
    {old_string:"send the Q3 invoice",new_string:"send the invoice"},
    {old_string:$i,new_string:"🆔 m-33333333"}]}}' | hook
assert_eq "$?" "2" "hook blocks a MultiEdit that rewrites an ID in a later edit"

# Outside 05-Tasks/ the UUID rule has nothing to say, and neither does the hook.
write_json "$VAULT/02-Sources/note.md" "$FIX/after-rewritten.md" | hook
assert_eq "$?" "0" "hook ignores files outside 05-Tasks/"
write_json "/somewhere/else/entirely.md" "$FIX/after-rewritten.md" | hook
assert_eq "$?" "0" "hook ignores files outside the vault"

# Symlinks can't dodge it.
ln -s "$TASKS_FILE" "$VAULT/02-Sources/alias-to-tasks.md"
write_json "$VAULT/02-Sources/alias-to-tasks.md" "$FIX/after-rewritten.md" | hook
assert_eq "$?" "2" "hook follows a symlink into 05-Tasks/"

# A hook that can't read its input must not block the session.
printf 'not json' | hook
assert_eq "$?" "1" "malformed input is a non-blocking error, not a block"

assert_eq "$(md5_of "$TASKS_FILE")" "$(md5_of "$FIX/before.md")" "the hook never writes the file itself"

assert_report
