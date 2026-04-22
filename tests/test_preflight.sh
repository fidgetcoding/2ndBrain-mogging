#!/usr/bin/env bash
# tests/test_preflight.sh
# Preflight + vault-validation guards on install.sh.
#
# Covers the documented failure modes:
#   - missing claude           → exit 10, message names the fix command
#   - missing jq               → exit 11, message tells the user to brew install
#   - --apply without --vault  → exit 20, message explains the required flag
#   - --vault contains '..'    → exit 21, message refuses for safety
#   - --vault not a directory  → exit 21, message points at the bad path
#   - dry-run has visible banner
#
# Strategy: we mock `claude` and `jq` by putting a constrained PATH at the top
# of a subshell. To simulate "claude missing", we strip claude out of PATH; to
# simulate "jq missing", we strip jq out. We never touch the user's real PATH.

set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/.." && pwd)"
# shellcheck source=./lib/assertions.sh
source "$HERE/lib/assertions.sh"

assert_reset "test_preflight"

TMPROOT="$(mktemp -d -t 2brain-preflight-XXXXXX)"
cleanup() {
  if [[ -n "${TMPROOT:-}" && ( "$TMPROOT" == /tmp/* || "$TMPROOT" == /var/folders/* ) ]]; then
    rm -rf "$TMPROOT"
  fi
}
trap cleanup EXIT

INSTALL_SH="$REPO_ROOT/install.sh"
if [[ ! -f "$INSTALL_SH" ]]; then
  printf "%sSKIP%s test_preflight (install.sh not present at %s)\n" \
    "${_C_YELLOW:-}" "${_C_RESET:-}" "$INSTALL_SH"
  exit 0
fi

# ---------------------------------------------------------------------------
# Build a tiny "clean" PATH containing only the binaries install.sh needs
# other than the one we want to simulate missing. This is defensive — running
# with PATH=/usr/bin:/bin is enough on macOS and Linux to find bash, git,
# awk, sed, grep, find, mktemp, osascript (macOS).
# ---------------------------------------------------------------------------
SAFE_PATH="/usr/bin:/bin:/usr/sbin:/sbin"
# Some macOS Homebrew tools live in /opt/homebrew/bin and /usr/local/bin; add
# them so jq resolves when we *don't* strip it.
for extra in /opt/homebrew/bin /usr/local/bin; do
  [[ -d "$extra" ]] && SAFE_PATH="$SAFE_PATH:$extra"
done

# Build a PATH that contains everything *except* claude. We do this by making
# a dedicated mock-dir that explicitly withholds the binary.
mock_path_without() {
  local strip="$1"
  local mock_dir="$TMPROOT/path-without-$strip"
  mkdir -p "$mock_dir"
  # Create symlinks to every tool in SAFE_PATH except the stripped one. This
  # guarantees PATH lookup can't accidentally resolve the real claude/jq in
  # a parent shell's $PATH.
  local IFS=':'
  for d in $SAFE_PATH; do
    [[ -d "$d" ]] || continue
    local f
    for f in "$d"/*; do
      [[ -x "$f" ]] || continue
      local bn; bn="$(basename "$f")"
      [[ "$bn" == "$strip" ]] && continue
      # First-wins — /usr/bin takes precedence over /usr/local/bin.
      [[ -e "$mock_dir/$bn" ]] && continue
      ln -s "$f" "$mock_dir/$bn" 2>/dev/null || true
    done
  done
  echo "$mock_dir"
}

# ---------------------------------------------------------------------------
# Case 1: missing claude → exit 10.
# ---------------------------------------------------------------------------
PATH_NO_CLAUDE="$(mock_path_without claude)"
set +e
NO_CLAUDE_OUT="$(PATH="$PATH_NO_CLAUDE" HOME="$TMPROOT/home" \
  bash "$INSTALL_SH" 2>&1)"
NO_CLAUDE_RC=$?
set -e 2>/dev/null || true

assert_eq "$NO_CLAUDE_RC" "10" "install.sh exits 10 when claude is missing"
if echo "$NO_CLAUDE_OUT" | grep -qiE 'claude.*(not installed|missing)'; then
  _pass "missing-claude error message names the missing binary"
else
  _fail "missing-claude error message did not mention claude"
  printf '  saw: %s\n' "${NO_CLAUDE_OUT:0:400}" 1>&2
fi
if echo "$NO_CLAUDE_OUT" | grep -qi 'cli-maxxing\|step-1-install'; then
  _pass "missing-claude error message points at cli-maxxing fix"
else
  _fail "missing-claude error did not link to cli-maxxing fix command"
fi

# ---------------------------------------------------------------------------
# Case 2: missing jq → exit 11.
# ---------------------------------------------------------------------------
# We need claude present but jq absent. Since we don't want to require a real
# claude on the tester's machine, we place a *fake* `claude` shim in the mock
# path that prints a high-enough version string to pass the version gate.
PATH_NO_JQ="$(mock_path_without jq)"
FAKE_CLAUDE="$TMPROOT/fake-claude-bin"
mkdir -p "$FAKE_CLAUDE"
cat > "$FAKE_CLAUDE/claude" <<'SHIM'
#!/usr/bin/env bash
if [[ "${1:-}" == "--version" ]]; then
  echo "2.1.0 (Claude Code)"
  exit 0
fi
exit 0
SHIM
chmod +x "$FAKE_CLAUDE/claude"

set +e
NO_JQ_OUT="$(PATH="$FAKE_CLAUDE:$PATH_NO_JQ" HOME="$TMPROOT/home" \
  bash "$INSTALL_SH" 2>&1)"
NO_JQ_RC=$?
set -e 2>/dev/null || true

assert_eq "$NO_JQ_RC" "11" "install.sh exits 11 when jq is missing"
if echo "$NO_JQ_OUT" | grep -qiE 'jq.*(not installed|missing)'; then
  _pass "missing-jq error message names the missing binary"
else
  _fail "missing-jq error message did not mention jq"
  printf '  saw: %s\n' "${NO_JQ_OUT:0:400}" 1>&2
fi
if echo "$NO_JQ_OUT" | grep -qi 'brew install jq\|apt-get install.*jq\|dnf install.*jq'; then
  _pass "missing-jq error message suggests package-manager fix"
else
  _fail "missing-jq error did not suggest a package-manager fix"
fi

# ---------------------------------------------------------------------------
# Case 3: --apply without --vault → exit 20.
# ---------------------------------------------------------------------------
# Full PATH so preflight passes; only validate_vault should fire.
set +e
NO_VAULT_OUT="$(HOME="$TMPROOT/home" \
  bash "$INSTALL_SH" --apply 2>&1)"
NO_VAULT_RC=$?
set -e 2>/dev/null || true

assert_eq "$NO_VAULT_RC" "20" "install.sh exits 20 when --apply is passed without --vault"
if echo "$NO_VAULT_OUT" | grep -qi '\-\-vault'; then
  _pass "missing-vault error message mentions --vault flag"
else
  _fail "missing-vault error did not mention --vault"
fi

# ---------------------------------------------------------------------------
# Case 4: --vault path contains '..' → exit 21 with traversal message.
# ---------------------------------------------------------------------------
DOTDOT_VAULT="$TMPROOT/parent/../parent"
mkdir -p "$TMPROOT/parent"
set +e
DOTDOT_OUT="$(HOME="$TMPROOT/home" \
  bash "$INSTALL_SH" --apply --vault "$DOTDOT_VAULT" 2>&1)"
DOTDOT_RC=$?
set -e 2>/dev/null || true

assert_eq "$DOTDOT_RC" "21" "install.sh exits 21 when --vault contains '..'"
if echo "$DOTDOT_OUT" | grep -qi "traversal\|'\.\.'\|\.\.[^a-zA-Z0-9]"; then
  _pass "traversal error message flags the '..' component"
else
  _fail "traversal error did not mention '..' or 'traversal'"
  printf '  saw: %s\n' "${DOTDOT_OUT:0:400}" 1>&2
fi

# ---------------------------------------------------------------------------
# Case 5: --vault points at a non-directory → exit 21.
# ---------------------------------------------------------------------------
NOEXIST="$TMPROOT/does-not-exist-$$"
set +e
NOEXIST_OUT="$(HOME="$TMPROOT/home" \
  bash "$INSTALL_SH" --apply --vault "$NOEXIST" 2>&1)"
NOEXIST_RC=$?
set -e 2>/dev/null || true

assert_eq "$NOEXIST_RC" "21" "install.sh exits 21 when --vault is not a directory"
if echo "$NOEXIST_OUT" | grep -qi 'not a directory\|does not exist'; then
  _pass "non-directory error mentions the missing folder"
else
  _fail "non-directory error did not clearly state missing folder"
fi

# ---------------------------------------------------------------------------
# Case 6: dry-run shows the visible banner.
#
# Default behavior (no flags) is dry-run. Even though nothing is written, the
# mode_banner() helper prints a fat box with "DRY-RUN MODE" inside it. Missing
# banner would make it impossible for a first-time user to tell whether their
# install actually ran.
#
# We seed a minimal valid settings.json so the jq-merge step in install.sh
# doesn't fail on an empty HOME (it uses `"$SETTINGS_PATH"` as a jq input file
# and needs valid JSON there). A fresh Claude Code install always has one.
# ---------------------------------------------------------------------------
DRY_HOME="$TMPROOT/home-dry"
mkdir -p "$DRY_HOME/.claude"
printf '{}\n' > "$DRY_HOME/.claude/settings.json"

set +e
DRY_OUT="$(HOME="$DRY_HOME" \
  bash "$INSTALL_SH" 2>&1)"
DRY_RC=$?
set -e 2>/dev/null || true

# dry-run without --vault is allowed and should exit 0.
assert_eq "$DRY_RC" "0" "install.sh exits 0 in default dry-run mode (no flags)"
if echo "$DRY_OUT" | grep -qi 'DRY-RUN MODE\|dry-run mode'; then
  _pass "dry-run mode shows visible 'DRY-RUN MODE' banner"
else
  _fail "dry-run mode did not show the DRY-RUN MODE banner"
  printf '  saw head: %s\n' "${DRY_OUT:0:400}" 1>&2
fi
if echo "$DRY_OUT" | grep -qiE 'would run|would install|would write'; then
  _pass "dry-run mode prints 'would …' preview lines"
else
  _fail "dry-run mode did not print any 'would …' preview line"
fi

assert_report
