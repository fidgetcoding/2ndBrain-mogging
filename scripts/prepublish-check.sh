#!/usr/bin/env bash
# ============================================================================
# scripts/prepublish-check.sh — local security gate, run before every release.
# ----------------------------------------------------------------------------
# Seven checks, fail-closed, in order:
#   1. gitleaks detect (custom config, no-git mode)
#   2. trufflehog filesystem (verified-only)
#   3. nathan.pii sweep — owner + private-client names
#   4. Presence of .gitleaks.toml and .github/workflows/secret-scan.yml
#   5. .gitignore includes "Claude-Memory"
#   6. LICENSE file present
#   7. Emit install.sh.sha256 (SHA-256 checksum for release artifacts)
#
# Exits non-zero on the first failure.
#
# Flags:
#   --skip-missing-tools   Treat missing required tools (gitleaks, trufflehog,
#                          shasum) as WARNINGS instead of hard failures. For
#                          local dev only — CI must never set this flag.
#   -h, --help             Show this help.
#
# Exit codes:
#   0   all gates passed
#   1   a check found a real problem (leaked secret, missing file, etc.)
#   10  a required tool is missing and --skip-missing-tools was NOT passed.
#       Distinct code so CI can tell "secret scan was not even run" apart
#       from "secret scan ran and found nothing/something".
# ============================================================================

set -euo pipefail

# Resolve repo root regardless of invocation cwd.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." &>/dev/null && pwd)"
cd "${REPO_ROOT}"

# ----------------------------------------------------------------------------
# Flag parsing. Keep it tiny — only --skip-missing-tools today.
# ----------------------------------------------------------------------------
SKIP_MISSING_TOOLS=0
usage() {
  sed -n '1,30p' "${BASH_SOURCE[0]}" | sed -n 's/^# \{0,1\}//p'
}
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-missing-tools) SKIP_MISSING_TOOLS=1; shift ;;
    -h|--help)            usage; exit 0 ;;
    *) printf 'unknown flag: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done

# Exit code dedicated to "tool not on PATH". Distinct from exit 1 so CI can
# loudly distinguish "scan did not run" from "scan ran clean/dirty".
MISSING_TOOL_EXIT=10

# ----------------------------------------------------------------------------
# ANSI helpers. No emoji — plain text so CI log parsers stay happy.
# ----------------------------------------------------------------------------
if [[ -t 1 ]]; then
  C_RED=$'\033[31m'; C_GRN=$'\033[32m'; C_YEL=$'\033[33m'; C_DIM=$'\033[2m'; C_RST=$'\033[0m'
else
  C_RED=""; C_GRN=""; C_YEL=""; C_DIM=""; C_RST=""
fi

step()    { printf '%s[step %s]%s %s\n' "${C_DIM}" "$1" "${C_RST}" "$2"; }
ok()      { printf '%s[ok]%s %s\n'   "${C_GRN}" "${C_RST}" "$1"; }
warn()    { printf '%s[warn]%s %s\n' "${C_YEL}" "${C_RST}" "$1"; }
fail()    { printf '%s[fail]%s %s\n' "${C_RED}" "${C_RST}" "$1" >&2; exit 1; }
# Missing-tool failure — exits MISSING_TOOL_EXIT (10) so CI can distinguish
# "scanner not installed" from "scanner found a secret" (exit 1).
fail_missing_tool() {
  printf '%s[fail]%s required tool not on PATH: %s\n' "${C_RED}" "${C_RST}" "$1" >&2
  printf '       pass --skip-missing-tools to downgrade to a warning (local dev only).\n' >&2
  exit "${MISSING_TOOL_EXIT}"
}
# require() hard-fails when the tool is missing UNLESS --skip-missing-tools is
# set, in which case it warns and returns non-zero so the caller can branch.
require() {
  if command -v "$1" >/dev/null 2>&1; then
    return 0
  fi
  if [[ "${SKIP_MISSING_TOOLS}" -eq 1 ]]; then
    warn "required tool not on PATH: $1 — skipping (--skip-missing-tools)"
    return 1
  fi
  fail_missing_tool "$1"
}

# ----------------------------------------------------------------------------
# Step 1 — gitleaks
# ----------------------------------------------------------------------------
step 1 "gitleaks detect --no-git"
if require gitleaks; then
  if ! gitleaks detect \
        --config .gitleaks.toml \
        --no-git \
        --redact \
        --exit-code 1; then
    fail "gitleaks found a secret — scrub before publishing"
  fi
  ok "gitleaks clean"
fi

# ----------------------------------------------------------------------------
# Step 2 — trufflehog
# ----------------------------------------------------------------------------
step 2 "trufflehog filesystem --only-verified"
if require trufflehog; then
  if ! trufflehog filesystem . \
        --only-verified \
        --fail \
        --no-update >/dev/null; then
    fail "trufflehog found a verified secret — rotate and scrub"
  fi
  ok "trufflehog clean"
fi

# ----------------------------------------------------------------------------
# Step 3 — owner/client PII sweep (uses local-only config/nathan.pii)
# ----------------------------------------------------------------------------
# The pattern list itself contains literal PII, so config/nathan.pii is
# gitignored. Contributors scaffold it from config/nathan.pii.example. If the
# local file is absent, the sweep is skipped with a loud warning — do NOT
# publish without running this sweep against a real pattern list.
# ----------------------------------------------------------------------------
step 3 "nathan.pii grep sweep"
if [[ ! -f config/nathan.pii ]]; then
  warn "config/nathan.pii not found — SKIPPING operator-specific PII sweep"
  warn "scaffold a local copy via: cp config/nathan.pii.example config/nathan.pii"
else
  # Strip comments + blank lines to a temp pattern file so grep -Ef doesn't
  # try to match literal `#` lines. mktemp is portable on macOS + Linux.
  PII_TMP="$(mktemp -t nathan-pii.XXXXXX)"
  trap 'rm -f "${PII_TMP}"' EXIT
  grep -vE '^\s*(#|$)' config/nathan.pii > "${PII_TMP}" || true

  # Only scan git-tracked files — gitignored files (private operator skills,
  # local-only configs) are never published and legitimately contain PII.
  # Exclude test fixtures and the gitleaks config (which references patterns).
  if git ls-files -z \
        -- ':!tests/fixtures' ':!.gitleaks.toml' ':!.gitleaks.private.toml' \
     | xargs -0 grep -IEn -f "${PII_TMP}" --; then
    fail "nathan.pii patterns matched — scrub before publishing"
  fi
  ok "nathan.pii sweep clean"
fi

# ----------------------------------------------------------------------------
# Step 4 — required security-gate files
# ----------------------------------------------------------------------------
step 4 "required security-gate files present"
required_files=(
  ".gitleaks.toml"
  ".github/workflows/secret-scan.yml"
)
for f in "${required_files[@]}"; do
  [[ -f "$f" ]] || fail "missing required file: $f"
done
ok "security-gate files present"

# ----------------------------------------------------------------------------
# Step 5 — .gitignore contains Claude-Memory
# ----------------------------------------------------------------------------
step 5 ".gitignore excludes Claude-Memory"
[[ -f .gitignore ]] || fail "missing .gitignore"
if ! grep -qE '(^|/)Claude-Memory' .gitignore; then
  fail ".gitignore is missing a Claude-Memory exclusion rule"
fi
ok ".gitignore excludes Claude-Memory"

# ----------------------------------------------------------------------------
# Step 6 — LICENSE present
# ----------------------------------------------------------------------------
step 6 "LICENSE present"
[[ -f LICENSE || -f LICENSE.md || -f LICENSE.txt ]] || fail "missing LICENSE file"
ok "LICENSE present"

# ----------------------------------------------------------------------------
# Step 7 — emit install.sh.sha256
# ----------------------------------------------------------------------------
step 7 "sha256(install.sh) > install.sh.sha256"
if require shasum; then
  if [[ ! -f install.sh ]]; then
    warn "install.sh not found — skipping checksum emission"
  else
    shasum -a 256 install.sh > install.sh.sha256
    ok "wrote install.sh.sha256 ($(awk '{print $1}' install.sh.sha256))"
  fi
fi

printf '\n%s[prepublish-check] all gates passed%s\n' "${C_GRN}" "${C_RST}"
