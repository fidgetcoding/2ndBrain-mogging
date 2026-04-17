#!/usr/bin/env bash
# tests/test_uuid_preservation.sh
# /save must never mutate Obsidian Tasks 🆔 UUIDs.

set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/.." && pwd)"
# shellcheck source=./lib/assertions.sh
source "$HERE/lib/assertions.sh"

assert_reset "test_uuid_preservation"

TMPROOT="$(mktemp -d -t 2brain-uuid-XXXXXX)"
cleanup() {
  if [[ -n "${TMPROOT:-}" && ( "$TMPROOT" == /tmp/* || "$TMPROOT" == /var/folders/* ) ]]; then
    rm -rf "$TMPROOT"
  fi
}
trap cleanup EXIT

VAULT="$TMPROOT/vault"
cp -R "$HERE/fixtures/sample-vault/." "$VAULT/"

# Seed a tasks file with 3 known UUIDs. Use fixed strings so we can grep
# byte-for-byte afterwards.
UUID1="abc123"
UUID2="def456"
UUID3="ghi789"
TASKS_FILE="$VAULT/06-Tasks/TASKS-UUID.md"

cat > "$TASKS_FILE" <<EOF
# TASKS-UUID

## Open

- [ ] uuid-task-one 🆔 ${UUID1} 📅 2026-05-01
- [ ] uuid-task-two 🆔 ${UUID2} ⏫
- [ ] uuid-task-three 🆔 ${UUID3} 🔁 every week
- [ ] plain-task-no-uuid

EOF

# Locate the save command. Skip if missing.
SAVE_CMD=""
for candidate in \
  "$REPO_ROOT/skills/save/run.sh" \
  "$REPO_ROOT/skills/save/save" \
  "$REPO_ROOT/bin/save" \
  "$REPO_ROOT/scripts/save.sh"
do
  if [[ -x "$candidate" ]]; then SAVE_CMD="$candidate"; break; fi
done

if [[ -z "$SAVE_CMD" ]]; then
  printf "%sSKIP%s test_uuid_preservation (no save command found)\n" \
    "${_C_YELLOW:-}" "${_C_RESET:-}"
  exit 0
fi

BEFORE_MD5="$(md5_of "$TASKS_FILE")"
BEFORE_COUNT="$(grep -c '🆔' "$TASKS_FILE" | tr -d ' ')"

# Invoke /save against the vault. We don't care about the summary output —
# only that UUIDs are preserved.
VAULT_DIR="$VAULT" "$SAVE_CMD" --yes >/dev/null 2>&1 || true

# ---------------------------------------------------------------------------
# Assertions.
# ---------------------------------------------------------------------------
assert_file "$TASKS_FILE" "tasks file still exists after /save"

assert_contains "$TASKS_FILE" "🆔 ${UUID1}" "UUID ${UUID1} preserved byte-for-byte"
assert_contains "$TASKS_FILE" "🆔 ${UUID2}" "UUID ${UUID2} preserved byte-for-byte"
assert_contains "$TASKS_FILE" "🆔 ${UUID3}" "UUID ${UUID3} preserved byte-for-byte"

AFTER_COUNT="$(grep -c '🆔' "$TASKS_FILE" | tr -d ' ')"
assert_eq "$AFTER_COUNT" "$BEFORE_COUNT" "UUID count unchanged ($BEFORE_COUNT)"

# No rogue UUIDs injected. We define "UUID" here loosely as '🆔 <token>' where
# token is not one of the three we planted, nor the empty string.
ROGUE=0
while IFS= read -r line; do
  tok="$(echo "$line" | sed -n 's/.*🆔[[:space:]]*\([A-Za-z0-9_-]\{1,\}\).*/\1/p')"
  [[ -z "$tok" ]] && continue
  case "$tok" in
    "$UUID1"|"$UUID2"|"$UUID3") ;;
    *) ROGUE=$((ROGUE + 1)) ;;
  esac
done < "$TASKS_FILE"
assert_eq "$ROGUE" "0" "no rogue UUIDs injected by /save"

# File content hash — if /save was a pure no-op, this matches. If /save
# legitimately updates non-UUID fields we soften to "no UUID drift" via the
# explicit UUID checks above. So we record, not assert, the full-file hash.
AFTER_MD5="$(md5_of "$TASKS_FILE")"
if [[ "$BEFORE_MD5" == "$AFTER_MD5" ]]; then
  _pass "tasks file byte-identical after /save (pure no-op)"
else
  # Not a failure — just informational.
  if [[ "${VERBOSE:-0}" == "1" ]]; then
    printf "  (info) file hash changed but UUIDs intact: %s -> %s\n" \
      "$BEFORE_MD5" "$AFTER_MD5"
  fi
fi

assert_report
