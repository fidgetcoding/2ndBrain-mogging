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
# Exits non-zero on the first failure. No --force, no --skip, no bypass.
# ============================================================================

set -euo pipefail

# Resolve repo root regardless of invocation cwd.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." &>/dev/null && pwd)"
cd "${REPO_ROOT}"

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
require() { command -v "$1" >/dev/null 2>&1 || fail "required tool not on PATH: $1"; }

# ----------------------------------------------------------------------------
# Step 1 — gitleaks
# ----------------------------------------------------------------------------
step 1 "gitleaks detect --no-git"
require gitleaks
if ! gitleaks detect \
      --config .gitleaks.toml \
      --no-git \
      --redact \
      --exit-code 1; then
  fail "gitleaks found a secret — scrub before publishing"
fi
ok "gitleaks clean"

# ----------------------------------------------------------------------------
# Step 2 — trufflehog
# ----------------------------------------------------------------------------
step 2 "trufflehog filesystem --only-verified"
require trufflehog
if ! trufflehog filesystem . \
      --only-verified \
      --fail \
      --no-update >/dev/null; then
  fail "trufflehog found a verified secret — rotate and scrub"
fi
ok "trufflehog clean"

# ----------------------------------------------------------------------------
# Step 3 — owner/client PII sweep
# ----------------------------------------------------------------------------
step 3 "nathan.pii grep sweep"
if [[ ! -f config/nathan.pii ]]; then
  fail "missing config/nathan.pii"
fi

# Strip comments + blank lines to a temp pattern file so grep -Ef doesn't
# try to match literal `#` lines. mktemp is portable on macOS + Linux.
PII_TMP="$(mktemp -t nathan-pii.XXXXXX)"
trap 'rm -f "${PII_TMP}"' EXIT
grep -vE '^\s*(#|$)' config/nathan.pii > "${PII_TMP}" || true

# -I skips binary, --exclude-dir drops .git + fixtures, --exclude drops
# the gitleaks config (which legitimately references these patterns).
if grep -rIEn -f "${PII_TMP}" . \
      --exclude-dir=.git \
      --exclude-dir=tests/fixtures \
      --exclude-dir=node_modules \
      --exclude=.gitleaks.toml \
      --exclude=nathan.pii; then
  fail "nathan.pii patterns matched — scrub before publishing"
fi
ok "nathan.pii sweep clean"

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
require shasum
if [[ ! -f install.sh ]]; then
  warn "install.sh not found — skipping checksum emission"
else
  shasum -a 256 install.sh > install.sh.sha256
  ok "wrote install.sh.sha256 ($(awk '{print $1}' install.sh.sha256))"
fi

printf '\n%s[prepublish-check] all gates passed%s\n' "${C_GRN}" "${C_RST}"
