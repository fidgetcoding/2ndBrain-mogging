#!/usr/bin/env bash
# tests/test_scope_guards.sh
# /wiki refuses to write into 06-Tasks/.
# - attempt --target 06-Tasks/INJECTED.md -> rc != 0, TASKS files unchanged
# - no INJECTED.md exists anywhere in the vault
# - writing into 02-Sources still works (positive control)

set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/.." && pwd)"
# shellcheck source=./lib/assertions.sh
source "$HERE/lib/assertions.sh"

assert_reset "test_scope_guards"

TMPROOT="$(mktemp -d -t 2brain-scope-XXXXXX)"
cleanup() {
  if [[ -n "${TMPROOT:-}" && ( "$TMPROOT" == /tmp/* || "$TMPROOT" == /var/folders/* ) ]]; then
    rm -rf "$TMPROOT"
  fi
}
trap cleanup EXIT

VAULT="$TMPROOT/vault"
cp -R "$HERE/fixtures/sample-vault/." "$VAULT/"

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
  # Forward-looking SKIP. The 06-Tasks scope guard is enforced by /wiki
  # which ships as a SKILL.md only — no shell entrypoint, so the forbidden
  # --target path cannot be exercised here. When a wiki CLI lands, this
  # test auto-activates via the candidate loop above.
  printf "%sSKIP%s test_scope_guards (no wiki CLI entrypoint — skill is SKILL.md-only)\n" \
    "${_C_YELLOW:-}" "${_C_RESET:-}"
  exit 0
fi

# ---------------------------------------------------------------------------
# Snapshot the 06-Tasks directory BEFORE any wiki invocation.
# ---------------------------------------------------------------------------
TASKS_BEFORE_SNAP="$TMPROOT/tasks.before"
snapshot_dir "$VAULT/06-Tasks" > "$TASKS_BEFORE_SNAP"

# ---------------------------------------------------------------------------
# Attempt forbidden target: 06-Tasks/INJECTED.md
# Expect non-zero return code.
# ---------------------------------------------------------------------------
FORBIDDEN_REL="06-Tasks/INJECTED.md"

set +e
VAULT_DIR="$VAULT" "$WIKI_CMD" add \
  --title "injected" \
  --body  "attacker payload" \
  --target "$FORBIDDEN_REL" \
  --yes </dev/null >/dev/null 2>&1
RC=$?
set -e 2>/dev/null || true

if [[ $RC -ne 0 ]]; then
  _pass "wiki returned non-zero on forbidden target ($FORBIDDEN_REL)"
else
  _fail "wiki returned 0 on forbidden target ($FORBIDDEN_REL)"
fi

# The INJECTED.md file must not exist anywhere in the vault.
INJECTED_HITS="$(find "$VAULT" -type f -name 'INJECTED.md' | wc -l | tr -d ' ')"
assert_eq "$INJECTED_HITS" "0" "no INJECTED.md anywhere in vault"

# 06-Tasks snapshot unchanged.
TASKS_AFTER_SNAP="$TMPROOT/tasks.after"
snapshot_dir "$VAULT/06-Tasks" > "$TASKS_AFTER_SNAP"

if diff -q "$TASKS_BEFORE_SNAP" "$TASKS_AFTER_SNAP" >/dev/null; then
  _pass "06-Tasks/ byte-identical after forbidden wiki attempt"
else
  _fail "06-Tasks/ changed despite scope-guard rejection"
  diff "$TASKS_BEFORE_SNAP" "$TASKS_AFTER_SNAP" 1>&2 || true
fi

# Specifically the fixture's TASKS-SAMPLE.md must be unchanged.
SAMPLE="$VAULT/06-Tasks/TASKS-SAMPLE.md"
if [[ -f "$SAMPLE" ]]; then
  SAMPLE_MD5_BEFORE="$(md5_of "$SAMPLE")"
  # We captured it already in the snapshot — recompute to be explicit.
  _pass "TASKS-SAMPLE.md still present (md5: $SAMPLE_MD5_BEFORE)"
fi

# ---------------------------------------------------------------------------
# Positive control: writing to 02-Sources succeeds.
# ---------------------------------------------------------------------------
LEGAL_REL="02-Sources/LIT-legal-target.md"
rm -f "$VAULT/$LEGAL_REL"

set +e
VAULT_DIR="$VAULT" "$WIKI_CMD" add \
  --title "legal-target" \
  --body  "this is allowed" \
  --target "$LEGAL_REL" \
  --yes </dev/null >/dev/null 2>&1
RC2=$?
set -e 2>/dev/null || true

assert_eq "$RC2" "0" "wiki succeeds on legal target (02-Sources)"
assert_file "$VAULT/$LEGAL_REL" "legal-target file actually created"

assert_report
