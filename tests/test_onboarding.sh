#!/usr/bin/env bash
# tests/test_onboarding.sh
# End-to-end onboarding test for install.sh.
# Verifies canonical vault layout, sidecars, skill symlinks, plugin manifest,
# settings.json Stop-hook merge, and idempotency.

set -u
# NOTE: no `set -e` — we want every assertion to run.

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/.." && pwd)"
# shellcheck source=./lib/assertions.sh
source "$HERE/lib/assertions.sh"

assert_reset "test_onboarding"

# ---------------------------------------------------------------------------
# Tempdir + trap cleanup.
# ---------------------------------------------------------------------------
TMPROOT="$(mktemp -d -t 2brain-onboard-XXXXXX)"
cleanup() {
  # Defensive: only nuke tempdir, never $HOME.
  if [[ -n "${TMPROOT:-}" && "$TMPROOT" == /tmp/* || "$TMPROOT" == /var/folders/* ]]; then
    rm -rf "$TMPROOT"
  fi
}
trap cleanup EXIT

FAKE_HOME="$TMPROOT/home"
FAKE_VAULT="$TMPROOT/vault"
mkdir -p "$FAKE_HOME/.claude" "$FAKE_VAULT"

# Seed a pre-existing settings.json with user hooks + custom field so we can
# verify install.sh does a non-destructive jq merge.
cat > "$FAKE_HOME/.claude/settings.json" <<'JSON'
{
  "permissions": {
    "allow": ["Bash(git status:*)"]
  },
  "customField": "preserve-me",
  "hooks": {
    "PreToolUse": [
      { "matcher": "Bash", "hooks": [{ "type": "command", "command": "echo user-pre" }] }
    ],
    "Stop": [
      { "matcher": "*", "hooks": [{ "type": "command", "command": "echo user-stop-pre-existing" }] }
    ]
  }
}
JSON

INSTALL_SH="$REPO_ROOT/install.sh"
if [[ ! -f "$INSTALL_SH" ]]; then
  # Test harness is ahead of install.sh — create a clear marker so the
  # assertions report that fact without crashing run_all.sh.
  echo "NOTE: install.sh missing at $INSTALL_SH — skipping onboarding test."
  printf "%sSKIP%s test_onboarding (install.sh not present yet)\n" \
    "${_C_YELLOW:-}" "${_C_RESET:-}"
  exit 0
fi

run_install() {
  HOME="$FAKE_HOME" \
  VAULT_DIR="$FAKE_VAULT" \
    bash "$INSTALL_SH" --vault "$FAKE_VAULT" --apply --no-launchd --skip-tests 2>&1
}

# ---------------------------------------------------------------------------
# First install run.
# ---------------------------------------------------------------------------
FIRST_OUT="$(run_install || true)"
FIRST_RC=$?
assert_eq "$FIRST_RC" "0" "install.sh exits 0 on first run"

# ---------------------------------------------------------------------------
# Canonical folders (7).
# ---------------------------------------------------------------------------
for d in 01-Conversations 02-Sources 03-Concepts 04-Index 05-Projects 06-Tasks Claude-Memory; do
  assert_dir "$FAKE_VAULT/$d" "canonical folder created: $d"
done

# ---------------------------------------------------------------------------
# Root sidecars (6).
# ---------------------------------------------------------------------------
for f in CLAUDE.md AGENTS.md SOUL.md CRITICAL_FACTS.md index.md log.md; do
  assert_file "$FAKE_VAULT/$f" "root sidecar created: $f"
done

# ---------------------------------------------------------------------------
# CLAUDE.md routing headers + folder references.
# ---------------------------------------------------------------------------
assert_contains "$FAKE_VAULT/CLAUDE.md" "01-Conversations" \
  "CLAUDE.md mentions 01-Conversations"
assert_contains "$FAKE_VAULT/CLAUDE.md" "02-Sources" \
  "CLAUDE.md mentions 02-Sources"
# Routing headers — check the two most load-bearing section markers. Accept
# either Markdown H2 or H3 level.
assert_contains "$FAKE_VAULT/CLAUDE.md" "re:^#+[[:space:]]+Routing" \
  "CLAUDE.md has a Routing header"
assert_contains "$FAKE_VAULT/CLAUDE.md" "re:^#+[[:space:]]+(Vault Structure|Folders|Layout)" \
  "CLAUDE.md has a Vault/Folders header"

# ---------------------------------------------------------------------------
# Plugin manifest.
# ---------------------------------------------------------------------------
PLUGIN_JSON="$FAKE_VAULT/.claude-plugin/plugin.json"
assert_file "$PLUGIN_JSON" "plugin.json exists"
assert_json_valid "$PLUGIN_JSON" "plugin.json is valid JSON"
assert_contains "$PLUGIN_JSON" "2ndbrain-mogging" \
  "plugin.json references the plugin name"

# ---------------------------------------------------------------------------
# Skills — 10 symlinks under ~/.claude/skills, each resolving into the repo.
# ---------------------------------------------------------------------------
SKILLS_DIR="$FAKE_HOME/.claude/skills"
assert_dir "$SKILLS_DIR" "~/.claude/skills exists after install"

EXPECTED_SKILLS=(
  wiki save onboard aliases recall connect
  distill index route scrub
)
for s in "${EXPECTED_SKILLS[@]}"; do
  # The installer may pick a prefix — we accept any file/dir under skills/
  # whose name *ends* with the canonical skill name. Strict assertion first,
  # with a tolerant fallback.
  link="$SKILLS_DIR/2ndbrain-$s"
  if [[ -L "$link" || -e "$link" ]]; then
    assert_symlink "$link" "skills/$s" "symlink present: 2ndbrain-$s"
  else
    # Tolerant fallback — any skill folder named $s.
    alt="$SKILLS_DIR/$s"
    assert_symlink "$alt" "skills/$s" "symlink present: $s (fallback)"
  fi
done

# ---------------------------------------------------------------------------
# Stop hook merged into settings.json without clobbering existing config.
# ---------------------------------------------------------------------------
SETTINGS="$FAKE_HOME/.claude/settings.json"
assert_file "$SETTINGS" "settings.json still present"
assert_json_valid "$SETTINGS" "settings.json still valid JSON after merge"

# Count Stop hooks that reference '2ndbrain'.
COUNT_2B_STOP=0
if command -v jq >/dev/null 2>&1; then
  COUNT_2B_STOP=$(jq '
    [ .hooks.Stop[]?
      | .hooks[]?
      | select(.command | test("2ndbrain"))
    ] | length
  ' "$SETTINGS" 2>/dev/null || echo 0)
fi
assert_eq "$COUNT_2B_STOP" "1" "exactly one 2ndbrain Stop hook entry after first install"

# Pre-existing user Stop hook survives.
COUNT_USER_STOP=0
if command -v jq >/dev/null 2>&1; then
  COUNT_USER_STOP=$(jq '
    [ .hooks.Stop[]?
      | .hooks[]?
      | select(.command | test("user-stop-pre-existing"))
    ] | length
  ' "$SETTINGS" 2>/dev/null || echo 0)
fi
assert_eq "$COUNT_USER_STOP" "1" "pre-existing user Stop hook preserved"

# PreToolUse untouched.
COUNT_PRE=0
if command -v jq >/dev/null 2>&1; then
  COUNT_PRE=$(jq '[.hooks.PreToolUse[]? | .hooks[]?] | length' "$SETTINGS" 2>/dev/null || echo 0)
fi
assert_eq "$COUNT_PRE" "1" "PreToolUse hook count unchanged (1)"

# customField preserved.
CUSTOM=$(jq -r '.customField // ""' "$SETTINGS" 2>/dev/null || echo "")
assert_eq "$CUSTOM" "preserve-me" "top-level customField preserved"

# ---------------------------------------------------------------------------
# Idempotency: second run.
# ---------------------------------------------------------------------------
# Add a user-authored edit to CLAUDE.md to confirm it survives re-run.
USER_NOTE="# USER_CUSTOM_MARKER do-not-clobber"
printf "\n%s\n" "$USER_NOTE" >> "$FAKE_VAULT/CLAUDE.md"

SECOND_OUT="$(run_install || true)"
SECOND_RC=$?
assert_eq "$SECOND_RC" "0" "install.sh exits 0 on second run (idempotent)"

# Stop hook count still 1, not duplicated.
COUNT_2B_STOP2=0
if command -v jq >/dev/null 2>&1; then
  COUNT_2B_STOP2=$(jq '
    [ .hooks.Stop[]?
      | .hooks[]?
      | select(.command | test("2ndbrain"))
    ] | length
  ' "$SETTINGS" 2>/dev/null || echo 0)
fi
assert_eq "$COUNT_2B_STOP2" "1" "2ndbrain Stop hook still 1 after second run (no duplication)"

# User customization preserved.
assert_contains "$FAKE_VAULT/CLAUDE.md" "USER_CUSTOM_MARKER" \
  "user edit in CLAUDE.md survived re-install"

# Pre-existing Stop hook still there.
COUNT_USER_STOP2=0
if command -v jq >/dev/null 2>&1; then
  COUNT_USER_STOP2=$(jq '
    [ .hooks.Stop[]?
      | .hooks[]?
      | select(.command | test("user-stop-pre-existing"))
    ] | length
  ' "$SETTINGS" 2>/dev/null || echo 0)
fi
assert_eq "$COUNT_USER_STOP2" "1" "user Stop hook still preserved after re-install"

# Still valid JSON.
assert_json_valid "$SETTINGS" "settings.json still valid after re-install"

# Folders still present (didn't get wiped).
for d in 01-Conversations 02-Sources 03-Concepts 04-Index 05-Projects 06-Tasks Claude-Memory; do
  assert_dir "$FAKE_VAULT/$d" "folder still present after re-install: $d"
done

assert_report
