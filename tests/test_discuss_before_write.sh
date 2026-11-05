#!/usr/bin/env bash
# tests/test_discuss_before_write.sh
# /wiki Add must prompt for confirmation before touching the vault. Runs bin/wiki,
# the write gate. The conversation that comes before it is the skill's to have.
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
    rm -rf "${TMPROOT:?}"
  fi
}
trap cleanup EXIT

VAULT="$TMPROOT/vault"
cp -R "$HERE/fixtures/sample-vault/." "$VAULT/"

WIKI_CMD="$REPO_ROOT/bin/wiki"
assert_file "$WIKI_CMD" "bin/wiki exists"

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
# Case 2: user types 'y' -> file is created under 02-Library/sources/.
# ---------------------------------------------------------------------------
TARGET_REL="02-Library/sources/LIT-confirm-write.md"
rm -f "${VAULT:?}/${TARGET_REL:?}"
printf 'y\n' | VAULT_DIR="$VAULT" "$WIKI_CMD" add \
  --title "confirm-write" \
  --body  "this should land on disk" \
  --target "$TARGET_REL" \
  >/dev/null 2>&1 || true

assert_file "$VAULT/$TARGET_REL" "file created after 'y' response"

# ---------------------------------------------------------------------------
# Case 3: --yes flag bypasses prompt (no stdin needed).
# ---------------------------------------------------------------------------
TARGET_REL2="02-Library/sources/LIT-auto-yes.md"
rm -f "${VAULT:?}/${TARGET_REL2:?}"
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
  --target "02-Library/sources/LIT-auto-yes-2.md" \
  --yes </dev/null 2>&1 || true)"
if echo "$YES_OUT" | grep -qi 'confirm\|proceed?\|(y/n)'; then
  _fail "--yes still emitted a confirmation prompt"
else
  _pass "--yes suppresses the confirmation prompt"
fi

# ---------------------------------------------------------------------------
# Case 4: no answer at all is a no. A closed stdin must not write.
# ---------------------------------------------------------------------------
TARGET_REL3="02-Library/sources/LIT-no-answer.md"
VAULT_DIR="$VAULT" "$WIKI_CMD" add \
  --title "no-answer" \
  --body "stdin is closed" \
  --target "$TARGET_REL3" \
  </dev/null >/dev/null 2>&1 || true
if [[ -e "$VAULT/$TARGET_REL3" ]]; then
  _fail "file created with no answer on stdin"
else
  _pass "no answer on stdin writes nothing"
fi

# ---------------------------------------------------------------------------
# Case 5: the prompt is real, and the preview shows the note before it.
# ---------------------------------------------------------------------------
PROMPT_OUT="$(printf 'n\n' | VAULT_DIR="$VAULT" "$WIKI_CMD" add \
  --title "preview-me" \
  --body "visible before the prompt" \
  --target "02-Library/sources/LIT-preview.md" 2>&1 || true)"
if printf '%s' "$PROMPT_OUT" | grep -q '(y/n)'; then
  _pass "without --yes it asks"
else
  _fail "without --yes it did not ask"
fi
if printf '%s' "$PROMPT_OUT" | grep -q 'visible before the prompt'; then
  _pass "the preview shows the note"
else
  _fail "the preview did not show the note"
fi

assert_report
