#!/usr/bin/env bash
# tests/test_discuss_before_write.sh
# /wiki Add must prompt for confirmation before touching the vault.
# - 'n' => no files change
# - 'y' => new file created
# - --yes flag => prompt bypassed

set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/.." && pwd)"
# shellcheck source=./lib/assertions.sh
source "$HERE/lib/assertions.sh"

assert_reset "test_discuss_before_write"

TMPROOT="$(mktemp -d -t 2brain-wiki-XXXXXX)"
cleanup() {
  if [[ -n "${TMPROOT:-}" && ( "$TMPROOT" == /tmp/* || "$TMPROOT" == /var/folders/* ) ]]; then
    rm -rf "$TMPROOT"
  fi
}
trap cleanup EXIT

VAULT="$TMPROOT/vault"
cp -R "$HERE/fixtures/sample-vault/." "$VAULT/"

# Locate the wiki command. We try a few canonical locations; if none exist we
# SKIP rather than fail — the test harness was written alongside a growing
# implementation.
WIKI_CMD=""
for candidate in \
  "$REPO_ROOT/skills/wiki/run.sh" \
  "$REPO_ROOT/skills/wiki/wiki" \
  "$REPO_ROOT/bin/wiki" \
  "$REPO_ROOT/scripts/wiki.sh"
do
  if [[ -x "$candidate" ]]; then WIKI_CMD="$candidate"; break; fi
done

if [[ -z "$WIKI_CMD" ]]; then
  printf "%sSKIP%s test_discuss_before_write (no wiki command found)\n" \
    "${_C_YELLOW:-}" "${_C_RESET:-}"
  exit 0
fi

# ---------------------------------------------------------------------------
# Pre-snapshot vault.
# ---------------------------------------------------------------------------
SNAP_BEFORE="$TMPROOT/snap.before"
snapshot_dir "$VAULT" > "$SNAP_BEFORE"
assert_line_count "$SNAP_BEFORE" "gt" "0" "pre-snapshot captured ≥1 file"

# ---------------------------------------------------------------------------
# Case 1: user types 'n' -> nothing changes.
# ---------------------------------------------------------------------------
SNAP_AFTER_N="$TMPROOT/snap.after_n"
printf 'n\n' | VAULT_DIR="$VAULT" "$WIKI_CMD" add \
  --title "should-not-land" \
  --body  "this must never hit disk" \
  >/dev/null 2>&1 || true
snapshot_dir "$VAULT" > "$SNAP_AFTER_N"

if diff -q "$SNAP_BEFORE" "$SNAP_AFTER_N" >/dev/null; then
  _pass "vault byte-identical after 'n' response"
else
  _fail "vault changed despite 'n' response"
  diff "$SNAP_BEFORE" "$SNAP_AFTER_N" 1>&2 || true
fi

# ---------------------------------------------------------------------------
# Case 2: user types 'y' -> file is created under 02-Sources/.
# ---------------------------------------------------------------------------
TARGET_REL="02-Sources/LIT-confirm-write.md"
rm -f "$VAULT/$TARGET_REL"
printf 'y\n' | VAULT_DIR="$VAULT" "$WIKI_CMD" add \
  --title "confirm-write" \
  --body  "this should land on disk" \
  --target "$TARGET_REL" \
  >/dev/null 2>&1 || true

assert_file "$VAULT/$TARGET_REL" "file created after 'y' response"

# ---------------------------------------------------------------------------
# Case 3: --yes flag bypasses prompt (no stdin needed).
# ---------------------------------------------------------------------------
TARGET_REL2="02-Sources/LIT-auto-yes.md"
rm -f "$VAULT/$TARGET_REL2"
VAULT_DIR="$VAULT" "$WIKI_CMD" add \
  --title "auto-yes" \
  --body  "--yes should skip prompt" \
  --target "$TARGET_REL2" \
  --yes </dev/null >/dev/null 2>&1 || true

assert_file "$VAULT/$TARGET_REL2" "file created when --yes is passed"

# Ensure prompt text did NOT echo to stdout when --yes (best-effort).
YES_OUT="$(VAULT_DIR="$VAULT" "$WIKI_CMD" add \
  --title "auto-yes-2" \
  --body "no prompt" \
  --target "02-Sources/LIT-auto-yes-2.md" \
  --yes </dev/null 2>&1 || true)"
if echo "$YES_OUT" | grep -qi 'confirm\|proceed?\|(y/n)'; then
  _fail "--yes still emitted a confirmation prompt"
else
  _pass "--yes suppresses the confirmation prompt"
fi

assert_report
