#!/usr/bin/env bash
# tests/run_all.sh — orchestrate all test_*.sh files
#
# Semantics:
#   PASS  → test script exited 0 AND never printed a "SKIP " sentinel line
#   SKIP  → test script exited 0 AND printed at least one "SKIP " sentinel line
#   FAIL  → test script exited non-zero
#
# The SKIP sentinel is a line starting with the literal "SKIP " (five chars,
# optionally preceded by an ANSI colour reset), emitted by tests when a
# prerequisite is missing. Without this parsing, skipped tests would look
# identical to passing tests and silently hide broken coverage.
#
# Flags:
#   [filter]   — substring match against basename
#   --strict   — promote every SKIP to FAIL (useful in CI once all skills
#                grow runnable entrypoints)

set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"

# macOS md5 → md5sum shim
if ! command -v md5sum >/dev/null 2>&1 && command -v md5 >/dev/null 2>&1; then
  md5sum() { md5 -q "$@"; }; export -f md5sum
fi

for bin in jq bash grep find mktemp; do
  command -v "$bin" >/dev/null 2>&1 || { echo "FATAL: missing $bin" >&2; exit 2; }
done

STRICT=0
filter=""
for arg in "$@"; do
  case "$arg" in
    --strict) STRICT=1 ;;
    --help|-h)
      cat <<EOF
Usage: $(basename "$0") [FILTER] [--strict]

  FILTER    Substring match on test basename (e.g. "onboarding")
  --strict  Promote SKIP results to FAIL (CI gate mode)
EOF
      exit 0
      ;;
    *) filter="$arg" ;;
  esac
done

pass=0; fail=0; skip=0; total=0
declare -a failed
declare -a skipped

if [[ -t 1 ]]; then
  G=$'\033[32m'; R=$'\033[31m'; Y=$'\033[33m'; B=$'\033[1m'; X=$'\033[0m'
else
  G=""; R=""; Y=""; B=""; X=""
fi

echo "${B}2ndBrain-mogging test harness${X}"
[[ -n "$filter" ]] && echo "Filter: $filter"
[[ $STRICT -eq 1 ]] && echo "Mode:   ${Y}strict${X} (SKIP → FAIL)"
echo

shopt -s nullglob
for t in "$HERE"/test_*.sh; do
  name="$(basename "$t")"
  [[ -n "$filter" && "$name" != *"$filter"* ]] && continue
  ((total++))
  echo "${B}→ $name${X}"

  # Capture combined stdout+stderr so we can scan for SKIP sentinels while
  # still mirroring output to the user's terminal in real time.
  # mktemp both the log + marker path so we never race another test.
  log_file="$(mktemp -t 2brain-test-log.XXXXXX)"
  if bash "$t" 2>&1 | tee "$log_file"; then
    rc=0
  else
    rc="${PIPESTATUS[0]}"
  fi

  # Detect SKIP sentinel. We accept either the leading ANSI yellow escape
  # (\033[33m) or a bare "SKIP " at the start of a line.
  is_skip=0
  if grep -qE '(^|\x1b\[[0-9;]*m)SKIP[[:space:]]' "$log_file" 2>/dev/null; then
    is_skip=1
  fi
  rm -f "$log_file"

  if [[ $rc -ne 0 ]]; then
    ((fail++)); failed+=("$name")
    echo "${R}✗ $name${X}"
  elif [[ $is_skip -eq 1 ]]; then
    if [[ $STRICT -eq 1 ]]; then
      ((fail++)); failed+=("$name (skipped under --strict)")
      echo "${R}✗ $name${X} (skip promoted to fail by --strict)"
    else
      ((skip++)); skipped+=("$name")
      echo "${Y}⊘ $name${X} (skipped)"
    fi
  else
    ((pass++))
    echo "${G}✓ $name${X}"
  fi
  echo
done
shopt -u nullglob

echo "${B}── Summary ──${X}"
printf "Total: %d  %sPassed: %d%s  %sSkipped: %d%s  %sFailed: %d%s\n" \
  "$total" "$G" "$pass" "$X" "$Y" "$skip" "$X" "$R" "$fail" "$X"

if ((skip > 0)); then
  echo "${Y}Skipped tests:${X}"
  for n in "${skipped[@]}"; do echo "  ${Y}⊘ $n${X}"; done
fi

if ((fail > 0)); then
  echo "${R}Failed tests:${X}"
  for n in "${failed[@]}"; do echo "  ${R}- $n${X}"; done
  exit 1
fi

if ((total == 0)); then
  echo "${R}No tests matched${X}"
  exit 2
fi

if ((pass == 0 && skip > 0)); then
  # Nothing actually exercised — loud warning but don't fail unless --strict
  echo "${Y}WARNING: every matched test skipped. No real coverage ran.${X}"
  [[ $STRICT -eq 1 ]] && exit 1
fi

echo "${G}ALL GREEN${X}"
