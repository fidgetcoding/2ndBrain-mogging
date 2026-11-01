#!/usr/bin/env bash
# tests/test_run_all_summary.sh
# run_all.sh must tell the truth in its last line: ALL GREEN only when every
# test ran and passed. Runs the real harness over throwaway test files.

set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib/assertions.sh
source "$HERE/lib/assertions.sh"

assert_reset "test_run_all_summary"

TMPROOT="$(mktemp -d -t 2brain-runall-XXXXXX)"
cleanup() {
  if [[ -n "${TMPROOT:-}" && ( "$TMPROOT" == /tmp/* || "$TMPROOT" == /var/folders/* ) ]]; then
    rm -rf "$TMPROOT"
  fi
}
trap cleanup EXIT

write_test() {
  local dir="$1" name="$2" body="$3"
  mkdir -p "$dir"
  printf '#!/usr/bin/env bash\n%s\n' "$body" > "$dir/test_$name.sh"
}
PASSES='exit 0'
SKIPS='echo "SKIP not runnable here"; exit 0'
FAILS='exit 1'

run_harness() {
  # Sets OUT and RC.
  local dir="$1"; shift
  OUT="$(RUN_ALL_TEST_DIR="$dir" bash "$HERE/run_all.sh" "$@" 2>&1)"
  RC=$?
}

assert_out_has() {
  if grep -qF -- "$1" <<<"$OUT"; then _pass "$2"; else _fail "$2 (output: ${OUT: -300})"; fi
}
assert_out_lacks() {
  if grep -qF -- "$1" <<<"$OUT"; then _fail "$2 (output: ${OUT: -300})"; else _pass "$2"; fi
}

# ---------------------------------------------------------------------------
# Case 1: everything ran and passed.
# ---------------------------------------------------------------------------
D1="$TMPROOT/all-pass"
write_test "$D1" a "$PASSES"
write_test "$D1" b "$PASSES"
run_harness "$D1"
assert_eq "$RC" "0" "all pass exits 0"
assert_out_has "ALL GREEN" "all pass says ALL GREEN"
assert_out_has "Total: 2  Passed: 2  Skipped: 0  Failed: 0" "all pass counts are right"

# ---------------------------------------------------------------------------
# Case 2: a skip is not green.
# ---------------------------------------------------------------------------
D2="$TMPROOT/with-skip"
write_test "$D2" a "$PASSES"
write_test "$D2" b "$SKIPS"
run_harness "$D2"
assert_eq "$RC" "0" "a skip alone still exits 0"
assert_out_lacks "ALL GREEN" "a skip never says ALL GREEN"
assert_out_has "PARTIAL: 1 passed, 1 skipped, 0 failed" "a skip says PARTIAL with counts"
assert_out_has "Total: 2  Passed: 1  Skipped: 1  Failed: 0" "a skip's counts are right"

# ---------------------------------------------------------------------------
# Case 3: --strict turns the skip into a failure.
# ---------------------------------------------------------------------------
run_harness "$D2" --strict
assert_eq "$RC" "1" "--strict exits 1 on a skip"
assert_out_lacks "ALL GREEN" "--strict with a skip never says ALL GREEN"

# ---------------------------------------------------------------------------
# Case 4: a failure wins over everything.
# ---------------------------------------------------------------------------
D4="$TMPROOT/with-fail"
write_test "$D4" a "$PASSES"
write_test "$D4" b "$SKIPS"
write_test "$D4" c "$FAILS"
run_harness "$D4"
assert_eq "$RC" "1" "a failure exits 1"
assert_out_lacks "ALL GREEN" "a failure never says ALL GREEN"
assert_out_lacks "PARTIAL" "a failure doesn't say PARTIAL"
assert_out_has "Total: 3  Passed: 1  Skipped: 1  Failed: 1" "a failure's counts are right"

# ---------------------------------------------------------------------------
# Case 5: every test skipped.
# ---------------------------------------------------------------------------
D5="$TMPROOT/all-skip"
write_test "$D5" a "$SKIPS"
run_harness "$D5"
assert_out_has "No real coverage ran" "all skipped warns that nothing ran"
assert_out_lacks "ALL GREEN" "all skipped never says ALL GREEN"

assert_report
