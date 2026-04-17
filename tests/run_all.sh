#!/usr/bin/env bash
# tests/run_all.sh — orchestrate all test_*.sh files
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"

# macOS md5 → md5sum shim
if ! command -v md5sum >/dev/null 2>&1 && command -v md5 >/dev/null 2>&1; then
  md5sum() { md5 -q "$@"; }; export -f md5sum
fi

for bin in jq bash grep find mktemp; do
  command -v "$bin" >/dev/null 2>&1 || { echo "FATAL: missing $bin" >&2; exit 2; }
done

filter="${1:-}"
pass=0; fail=0; total=0
declare -a failed

if [[ -t 1 ]]; then G=$'\033[32m'; R=$'\033[31m'; B=$'\033[1m'; X=$'\033[0m'; else G=""; R=""; B=""; X=""; fi

echo "${B}2ndBrain-mogging test harness${X}"
[[ -n "$filter" ]] && echo "Filter: $filter"
echo

shopt -s nullglob
for t in "$HERE"/test_*.sh; do
  name="$(basename "$t")"
  [[ -n "$filter" && "$name" != *"$filter"* ]] && continue
  ((total++))
  echo "${B}→ $name${X}"
  if bash "$t"; then ((pass++)); echo "${G}✓ $name${X}"
  else ((fail++)); failed+=("$name"); echo "${R}✗ $name${X}"; fi
  echo
done
shopt -u nullglob

echo "${B}── Summary ──${X}"
echo "Total: $total  ${G}Passed: $pass${X}  ${R}Failed: $fail${X}"
((fail > 0)) && { for n in "${failed[@]}"; do echo "  ${R}- $n${X}"; done; exit 1; }
((total == 0)) && { echo "${R}No tests matched${X}"; exit 2; }
echo "${G}ALL GREEN${X}"
