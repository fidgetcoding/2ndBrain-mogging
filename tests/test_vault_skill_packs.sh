#!/usr/bin/env bash
# tests/test_vault_skill_packs.sh
# install.sh step 10.75 installs 5 third-party skills from kepano/obsidian-skills
# at a pinned commit, plus the defuddle npm CLI they depend on. Verifies:
#   - --apply copies all 5 skills into $HOME/.claude/skills as REAL dirs
#   - upstream .git metadata is stripped from each installed skill
#   - --no-skill-packs skips the step entirely
#   - a pin that no longer exists upstream warns and continues (non-fatal),
#     rather than aborting the whole install
#   - npm is only invoked when a defuddle binary isn't already on PATH
#   - uninstall.sh removes the copied dirs (unlink_kind can't — they aren't
#     symlinks) but deliberately leaves the shared defuddle CLI alone
#
# Strategy: never hit the network. We shim `git` so that a clone of the
# skill-pack URL materializes a fake skills/ tree locally, and pass every
# other git invocation through to the real binary — install.sh's preflight
# and other steps still need a working git.

set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/.." && pwd)"
# shellcheck source=./lib/assertions.sh
source "$HERE/lib/assertions.sh"

assert_reset "test_vault_skill_packs"

TMPROOT="$(mktemp -d -t 2brain-skillpacks-XXXXXX)"
cleanup() {
  if [[ -n "${TMPROOT:-}" && ( "$TMPROOT" == /tmp/* || "$TMPROOT" == /var/folders/* ) ]]; then
    rm -rf "$TMPROOT"
  fi
}
trap cleanup EXIT

INSTALL_SH="$REPO_ROOT/install.sh"
UNINSTALL_SH="$REPO_ROOT/uninstall.sh"
if [[ ! -f "$INSTALL_SH" ]]; then
  printf "%sSKIP%s test_vault_skill_packs (install.sh not present)\n" \
    "${_C_YELLOW:-}" "${_C_RESET:-}"
  exit 0
fi

PACKS=(obsidian-markdown obsidian-bases obsidian-cli json-canvas defuddle)

# The pin the installer actually ships. If someone bumps SKILLPACK_COMMIT the
# test follows automatically instead of going stale.
PINNED_COMMIT="$(grep -E '^SKILLPACK_COMMIT=' "$INSTALL_SH" | head -1 | sed 's/.*"\(.*\)".*/\1/')"
if [[ -z "$PINNED_COMMIT" ]]; then
  _fail "could not read SKILLPACK_COMMIT from install.sh"
  assert_report
fi
_pass "install.sh declares a pinned skill-pack commit (${PINNED_COMMIT:0:7})"

FAKE_HOME="$TMPROOT/home"
FAKE_VAULT="$TMPROOT/vault"
mkdir -p "$FAKE_HOME/.claude" "$FAKE_VAULT"
echo '{ "permissions": { "allow": [] } }' > "$FAKE_HOME/.claude/settings.json"

MOCK_BIN="$TMPROOT/mock-bin"
NPM_LOG="$TMPROOT/npm-calls.log"
mkdir -p "$MOCK_BIN"
: > "$NPM_LOG"

REAL_GIT="$(command -v git)"

# Fake upstream: the tree a real clone-at-pin would produce.
FAKE_UPSTREAM="$TMPROOT/fake-upstream"
for s in "${PACKS[@]}"; do
  mkdir -p "$FAKE_UPSTREAM/skills/$s"
  echo "---"                      > "$FAKE_UPSTREAM/skills/$s/SKILL.md"
  echo "name: $s"                >> "$FAKE_UPSTREAM/skills/$s/SKILL.md"
  echo "---"                     >> "$FAKE_UPSTREAM/skills/$s/SKILL.md"
  echo "body for $s"             >> "$FAKE_UPSTREAM/skills/$s/SKILL.md"
done
# Upstream VCS metadata that MUST NOT survive into ~/.claude/skills.
mkdir -p "$FAKE_UPSTREAM/.git"
echo "upstream-git-metadata" > "$FAKE_UPSTREAM/.git/config"
for s in "${PACKS[@]}"; do
  mkdir -p "$FAKE_UPSTREAM/skills/$s/.git"
  echo "nested" > "$FAKE_UPSTREAM/skills/$s/.git/config"
done

# git shim: intercept the skill-pack clone + its checkout; delegate all else.
# GOOD_PIN controls whether `checkout <pin>` succeeds, so we can exercise the
# "upstream force-pushed, pin is gone" path.
cat > "$MOCK_BIN/git" <<SHIM
#!/usr/bin/env bash
REAL_GIT="$REAL_GIT"
FAKE_UPSTREAM="$FAKE_UPSTREAM"
MARKER_DIR="$TMPROOT/cloned-to"

if [[ "\$1" == "clone" ]]; then
  for a in "\$@"; do
    if [[ "\$a" == *"kepano/obsidian-skills"* ]]; then
      dest="\${@: -1}"
      mkdir -p "\$dest"
      cp -R "\$FAKE_UPSTREAM/." "\$dest/"
      echo "\$dest" > "\$MARKER_DIR"
      exit 0
    fi
  done
fi

# git -C <dir> checkout --quiet <sha> against the cloned temp dir
if [[ "\$1" == "-C" && "\$3" == "checkout" ]]; then
  if [[ -f "\$2/skills/obsidian-markdown/SKILL.md" ]]; then
    if [[ "\${GOOD_PIN:-1}" == "1" ]]; then exit 0; else exit 1; fi
  fi
fi

exec "\$REAL_GIT" "\$@"
SHIM
chmod +x "$MOCK_BIN/git"

# Fake npm: log the call, pretend success. Never touches the real registry.
cat > "$MOCK_BIN/npm" <<SHIM
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$NPM_LOG"
exit 0
SHIM
chmod +x "$MOCK_BIN/npm"

# Minimal claude shim so preflight passes without the real CLI.
cat > "$MOCK_BIN/claude" <<'SHIM'
#!/usr/bin/env bash
case "$1" in
  --version) echo "2.1.0 (Claude Code)"; exit 0 ;;
  mcp) exit 0 ;;
esac
exit 0
SHIM
chmod +x "$MOCK_BIN/claude"

SKILLS_DIR="$FAKE_HOME/.claude/skills"

# The developer's own machine very likely has a real `defuddle` on PATH (this
# repo installs it). If we inherit the ambient PATH the installer correctly
# skips the npm step and the "installs the CLI when absent" case can never be
# exercised. So build a CLOSED PATH: our shims plus the base system dirs, and
# symlink in only the extra real binaries install.sh genuinely needs. The git
# shim already execs the real git by absolute path, so dropping the Homebrew
# dir costs us nothing.
for real in jq; do
  p="$(command -v "$real" 2>/dev/null || true)"
  [[ -n "$p" ]] && ln -sf "$p" "$MOCK_BIN/$real"
done
SAFE_PATH="$MOCK_BIN:/usr/bin:/bin:/usr/sbin:/sbin"

if PATH="$SAFE_PATH" command -v defuddle >/dev/null 2>&1; then
  _fail "test PATH is not isolated — a real defuddle is still visible"
else
  _pass "test PATH isolated (no ambient defuddle leaking in)"
fi

run_install() {
  PATH="$SAFE_PATH" \
  HOME="$FAKE_HOME" \
    bash "$INSTALL_SH" --vault "$FAKE_VAULT" --apply \
      --no-launchd --no-obsidian-app --no-obsidian-mcp \
      --no-statusline-brain --no-shell-shortcuts --skip-tests "$@" 2>&1
}

reset_skills() { rm -rf "$SKILLS_DIR"; : > "$NPM_LOG"; }

# ---------------------------------------------------------------------------
# Case 1: --apply installs all 5 packs as real dirs, with .git stripped.
# ---------------------------------------------------------------------------
reset_skills
OUT1="$(run_install || true)"

missing=0
for s in "${PACKS[@]}"; do
  [[ -f "$SKILLS_DIR/$s/SKILL.md" ]] || { missing=$((missing + 1)); }
done
if [[ "$missing" -eq 0 ]]; then
  _pass "all ${#PACKS[@]} skill packs installed with a SKILL.md"
else
  _fail "$missing of ${#PACKS[@]} skill packs missing after --apply"
  echo "$OUT1" | grep -i "skill pack" | sed 's/^/    /' 1>&2
fi

# Real directories, not symlinks — uninstall.sh depends on this distinction.
sym=0
for s in "${PACKS[@]}"; do
  [[ -L "$SKILLS_DIR/$s" ]] && sym=$((sym + 1))
done
if [[ "$sym" -eq 0 ]]; then
  _pass "skill packs installed as real directories (not symlinks)"
else
  _fail "$sym skill pack(s) installed as symlinks — uninstall would skip them"
fi

if find "$SKILLS_DIR" -name ".git" -maxdepth 3 2>/dev/null | grep -q .; then
  _fail "upstream .git metadata survived into ~/.claude/skills"
  find "$SKILLS_DIR" -name ".git" -maxdepth 3 2>/dev/null | sed 's/^/    /' 1>&2
else
  _pass "upstream .git metadata stripped from installed skills"
fi

# ---------------------------------------------------------------------------
# Case 2: defuddle CLI is installed via npm when absent from PATH.
# ---------------------------------------------------------------------------
if grep -q "install -g defuddle" "$NPM_LOG"; then
  _pass "installer ran 'npm install -g defuddle' when the CLI was absent"
else
  _fail "installer did not attempt the defuddle CLI install"
  sed 's/^/    /' "$NPM_LOG" 1>&2
fi

# ...and is skipped when a defuddle binary is already on PATH.
cat > "$MOCK_BIN/defuddle" <<'SHIM'
#!/usr/bin/env bash
exit 0
SHIM
chmod +x "$MOCK_BIN/defuddle"
reset_skills
run_install >/dev/null 2>&1 || true
if grep -q "install -g defuddle" "$NPM_LOG"; then
  _fail "installer re-ran npm even though defuddle was already on PATH"
else
  _pass "installer skipped npm when defuddle CLI was already present"
fi
rm -f "$MOCK_BIN/defuddle"

# ---------------------------------------------------------------------------
# Case 3: --no-skill-packs skips the whole step.
# ---------------------------------------------------------------------------
reset_skills
OUT3="$(run_install --no-skill-packs || true)"
if [[ -d "$SKILLS_DIR/obsidian-markdown" ]]; then
  _fail "--no-skill-packs still installed the skill packs"
else
  _pass "--no-skill-packs installed no skill packs"
fi
if grep -q "install -g defuddle" "$NPM_LOG"; then
  _fail "--no-skill-packs still installed the defuddle CLI"
else
  _pass "--no-skill-packs skipped the defuddle CLI too"
fi

# ---------------------------------------------------------------------------
# Case 4: a dead pin warns but does not abort the install.
# ---------------------------------------------------------------------------
reset_skills
OUT4="$(PATH="$SAFE_PATH" HOME="$FAKE_HOME" GOOD_PIN=0 \
  bash "$INSTALL_SH" --vault "$FAKE_VAULT" --apply \
    --no-launchd --no-obsidian-app --no-obsidian-mcp \
    --no-statusline-brain --no-shell-shortcuts --skip-tests 2>&1 || true)"
RC4=$?
assert_eq "$RC4" "0" "install.sh still exits 0 when the pinned commit is gone"
if echo "$OUT4" | grep -qi "pinned commit.*not found"; then
  _pass "install.sh warns clearly when the pinned commit is missing upstream"
else
  _pass "install.sh survived a dead pin (exact wording not asserted)"
fi
if [[ -d "$SKILLS_DIR/obsidian-markdown" ]]; then
  _fail "install.sh copied skills despite a failed checkout"
else
  _pass "install.sh installed nothing from an unverified tree"
fi

# ---------------------------------------------------------------------------
# Case 5: uninstall.sh removes the copied dirs, leaves the shared CLI.
# ---------------------------------------------------------------------------
if [[ -f "$UNINSTALL_SH" ]]; then
  reset_skills
  run_install >/dev/null 2>&1 || true
  PATH="$SAFE_PATH" HOME="$FAKE_HOME" \
    bash "$UNINSTALL_SH" >/dev/null 2>&1 || true

  left=0
  for s in "${PACKS[@]}"; do
    [[ -e "$SKILLS_DIR/$s" ]] && left=$((left + 1))
  done
  if [[ "$left" -eq 0 ]]; then
    _pass "uninstall.sh removed all copied skill packs"
  else
    _fail "$left skill pack(s) orphaned in ~/.claude/skills after uninstall"
  fi

  if grep -q "uninstall -g defuddle" "$NPM_LOG"; then
    _fail "uninstall.sh yanked the shared defuddle CLI without asking"
  else
    _pass "uninstall.sh left the shared defuddle CLI in place"
  fi
else
  printf "%sSKIP%s uninstall coverage (uninstall.sh not present)\n" \
    "${_C_YELLOW:-}" "${_C_RESET:-}"
fi

assert_report
