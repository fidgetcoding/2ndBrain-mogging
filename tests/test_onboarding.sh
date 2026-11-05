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
  # Defensive: only nuke tempdir, never $HOME. Explicit parens because bash
  # treats unparenthesised `A && B || C` as ambiguous — we need
  # "set AND (inside /tmp OR inside /var/folders)".
  if [[ -n "${TMPROOT:-}" && ( "$TMPROOT" == /tmp/* || "$TMPROOT" == /var/folders/* ) ]]; then
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
  # CI matrix runs this on macos-latest where /Applications/Obsidian.app is
  # absent and Homebrew IS on PATH — without --no-obsidian-app the installer
  # would attempt a real `brew install --cask obsidian` (slow + flaky in CI).
  # The other --no-* flags isolate the install to the temp HOME.
  HOME="$FAKE_HOME" \
  CLAUDE_HOME="$FAKE_HOME/.claude" \
  VAULT_DIR="$FAKE_VAULT" \
    bash "$INSTALL_SH" --vault "$FAKE_VAULT" --apply \
      --no-launchd --no-obsidian-app --no-obsidian-mcp \
      --no-statusline-brain --no-shell-shortcuts --no-skill-packs --skip-tests 2>&1
}

# ---------------------------------------------------------------------------
# First install run.
#
# We capture stdout/stderr into FIRST_OUT so VERBOSE=1 runs can surface
# installer output on failure. set -e is off by design (see header), so a
# failing install keeps the harness going and its exit code is read here. shellcheck SC2034 would flag
# FIRST_OUT as unused — the reference below both satisfies the linter and
# prints the captured output when debugging.
# ---------------------------------------------------------------------------
FIRST_RC=0
FIRST_OUT="$(run_install)" || FIRST_RC=$?
assert_eq "$FIRST_RC" "0" "install.sh exits 0 on first run"
[[ "${VERBOSE:-0}" == "1" ]] && printf '%s\n' "$FIRST_OUT"

# ---------------------------------------------------------------------------
# The template itself is minimal: the numbered folders, the notes every skill
# needs, the root rule files, a deletable README guide, and the Claude-Memory
# examples. No example projects. A file added to or dropped from
# vault-template/ fails here until this list is updated on purpose.
# ---------------------------------------------------------------------------
EXPECTED_TEMPLATE='01-Projects/VAULT/VAULT.md
02-Library/ideas/.gitkeep
02-Library/people/.gitkeep
02-Library/sources/.gitkeep
02-Library/tools/.gitkeep
03-Index/Index.md
03-Index/Projects-Index.md
04-Tasks/TASKS.md
AGENTS.md
CLAUDE.md
Claude-Memory/aliases.example.yaml
Claude-Memory/memory-tier.example.yaml
README.md
SOUL.md'
ACTUAL_TEMPLATE="$(cd "$REPO_ROOT/vault-template" && find . -type f ! -name .DS_Store | sed 's#^\./##' | LC_ALL=C sort)"
assert_eq "$ACTUAL_TEMPLATE" "$(printf '%s\n' "$EXPECTED_TEMPLATE" | LC_ALL=C sort)" "vault-template/ holds exactly the minimal file set"

# ---------------------------------------------------------------------------
# Canonical folders: the four numbered ones, 02-Library's four, VAULT/, and
# the Claude-Memory link.
# ---------------------------------------------------------------------------
for d in 01-Projects 01-Projects/VAULT 02-Library 02-Library/people 02-Library/tools 02-Library/ideas 02-Library/sources 03-Index 04-Tasks Claude-Memory; do
  assert_dir "$FAKE_VAULT/$d" "canonical folder created: $d"
done
# Library v2 retired these; a fresh install must not create them.
for d in 02-Sources 03-Concepts; do
  if [[ -e "$FAKE_VAULT/$d" ]]; then _fail "retired folder created: $d"; else _pass "retired folder not created: $d"; fi
done
# No example projects. The catch-all, the vault log and the reports folder are
# made by /save, /wiki and the agents the first time they need them.
for p in example-project-1 example-project-2 example-project-3 INCUBATOR MISC VAULT/log.md VAULT/REPORTS; do
  if [[ -e "$FAKE_VAULT/01-Projects/$p" ]]; then _fail "seeded but should be made on demand: 01-Projects/$p"; else _pass "not seeded: 01-Projects/$p"; fi
done
PROJECTS_LS="$(cd "$FAKE_VAULT/01-Projects" && ls -A | grep -v '^\.DS_Store$' | tr '\n' ' ')"
assert_eq "$PROJECTS_LS" "VAULT " "01-Projects/ holds only VAULT/ after a fresh install"

# ---------------------------------------------------------------------------
# Root files: the three rule files, plus the README guide in a fresh vault.
# ---------------------------------------------------------------------------
for f in CLAUDE.md AGENTS.md SOUL.md README.md; do
  assert_file "$FAKE_VAULT/$f" "root file created: $f"
done
for f in CRITICAL_FACTS.md index.md log.md; do
  if [[ -e "$FAKE_VAULT/$f" ]]; then _fail "retired root file created: $f"; else _pass "retired root file not created: $f"; fi
done
assert_contains "$FAKE_VAULT/SOUL.md" "re:^#+[[:space:]]+Critical facts" "SOUL.md carries the Critical facts section"
for f in 01-Projects/VAULT/VAULT.md 03-Index/Index.md 03-Index/Projects-Index.md 04-Tasks/TASKS.md; do
  assert_file "$FAKE_VAULT/$f" "seeded: $f"
done
# Chat folders are named !!conversations since 2026-11-05; reports never live in one.
if find "$FAKE_VAULT/01-Projects" -type d -name conversations | grep -q .; then _fail "a plain conversations/ folder was seeded"; else _pass "no plain conversations/ folder seeded"; fi

# Projects-Index lists only what exists: VAULT, no example projects.
assert_contains "$FAKE_VAULT/03-Index/Projects-Index.md" "[[VAULT]]" "Projects-Index lists VAULT"
for gone in example-project INCUBATOR '[[MISC]]'; do
  assert_not_contains "$FAKE_VAULT/03-Index/Projects-Index.md" "$gone" "Projects-Index has no link for an unseeded folder: $gone"
done
# The seeded aliases starter keeps the catch-all and VAULT, and nothing else.
assert_contains "$FAKE_VAULT/Claude-Memory/aliases.yaml" '"catch-all"' "aliases.yaml keeps the catch-all entry"
assert_contains "$FAKE_VAULT/Claude-Memory/aliases.yaml" "path: 01-Projects/VAULT" "aliases.yaml lists VAULT"
for gone in example-project INCUBATOR; do
  assert_not_contains "$FAKE_VAULT/Claude-Memory/aliases.yaml" "$gone" "aliases.yaml has no entry for $gone"
done

# The README guide: example trees, the structure grid, the never-delete list.
README_V="$FAKE_VAULT/README.md"
assert_contains "$README_V" "re:^#+[[:space:]]+Never delete these" "README has a Never delete these section"
assert_contains "$README_V" "| Folder | What goes in it | Example |" "README has the structure grid"
assert_contains "$README_V" "re:^#+[[:space:]]+Example: a small vault" "README has a small example tree"
assert_contains "$README_V" "re:^#+[[:space:]]+Example: a busier vault" "README has a busier example tree"
for keep in '`01-Projects/`' '`02-Library/`' '`people/`' '`tools/`' '`ideas/`' '`sources/`' '`Index.md`' '`Projects-Index.md`' '`TASKS.md`' '`VAULT.md`' '`CLAUDE.md`' '`AGENTS.md`' '`SOUL.md`' '`Claude-Memory`'; do
  assert_contains "$README_V" "$keep" "README names $keep"
done
for rule in '!!conversations/' '!ARCHIVE/' '-ARCHIVE.md' '-MISC.md' 'REPO/' 'ALL CAPS'; do
  assert_contains "$README_V" "$rule" "README teaches: $rule"
done
assert_contains "$README_V" "re:[Dd]elete it" "README says it can be deleted"

# Each scheduled agent makes the reports folder before it runs.
for plist in "$REPO_ROOT"/scheduled/launchd/*.plist; do
  assert_contains "$plist" "mkdir -p 01-Projects/VAULT/REPORTS" "$(basename "$plist") makes REPORTS/ first"
done

# ---------------------------------------------------------------------------
# CLAUDE.md routing headers + folder references.
# ---------------------------------------------------------------------------
assert_contains "$FAKE_VAULT/CLAUDE.md" "01-Projects" \
  "CLAUDE.md mentions 01-Projects"
assert_contains "$FAKE_VAULT/CLAUDE.md" "02-Library" \
  "CLAUDE.md mentions 02-Library"
# Routing headers — check the two most load-bearing section markers. Accept
# either Markdown H2 or H3 level.
assert_contains "$FAKE_VAULT/CLAUDE.md" "re:^#+[[:space:]]+Routing" \
  "CLAUDE.md has a Routing header"
# Accept any of: "Vault Structure", "Folder structure", "Folders", "Layout".
# Case-insensitive via [Ff]/[Ss] character classes because posix-ERE has no
# inline (?i) and CLAUDE.md uses "Folder structure" (sentence case).
assert_contains "$FAKE_VAULT/CLAUDE.md" "re:^#+[[:space:]]+([Vv]ault [Ss]tructure|[Ff]older [Ss]tructure|[Ff]olders|[Ll]ayout)" \
  "CLAUDE.md has a Vault/Folders header"

# ---------------------------------------------------------------------------
# Plugin manifest (repo-root, NOT vault).
#
# plugin.json is the Claude Code marketplace/pack manifest. It lives at
# $REPO_ROOT/.claude-plugin/plugin.json and is read by Claude Code when the
# pack is registered — install.sh does not copy it into the user's vault.
# The old assertions looked in $VAULT/.claude-plugin/plugin.json which was
# a category error; we now assert against the repo.
# ---------------------------------------------------------------------------
PLUGIN_JSON="$REPO_ROOT/.claude-plugin/plugin.json"
assert_file "$PLUGIN_JSON" "plugin.json exists in repo"
assert_json_valid "$PLUGIN_JSON" "plugin.json is valid JSON"
assert_contains "$PLUGIN_JSON" "2ndbrain-mogging" \
  "plugin.json references the plugin name"

# ---------------------------------------------------------------------------
# Skills — ship surface is 13 skills total: 11 core + 2 optional importers.
# Symlinked into ~/.claude/skills WITHOUT any namespace prefix. install.sh's
# symlink_dir "skills" iterates every entry under repo/skills/, so all 12
# directories should land even if plugin.json's .skills[] array only advertises
# the 10 core ones (import-claude + import-notes are discoverable via /skill
# but intentionally omitted from the marketplace manifest for a leaner first
# impression — README.md line 25 explicitly calls them "10 core + 2 optional
# importers").
#
# The old EXPECTED_SKILLS list included phantom skills (onboard, recall,
# distill, index, route, scrub) that were never implemented; those
# assertions have been removed. If/when any of them ship, add them back
# here and update plugin.json in the same change.
# ---------------------------------------------------------------------------
SKILLS_DIR="$FAKE_HOME/.claude/skills"
assert_dir "$SKILLS_DIR" "\$HOME/.claude/skills exists after install"

EXPECTED_SKILLS=(
  save wiki challenge emerge backfill
  aliases autoresearch canvas tether connect
  import-claude import-notes vault-coach
)
for s in "${EXPECTED_SKILLS[@]}"; do
  link="$SKILLS_DIR/$s"
  assert_symlink "$link" "skills/$s" "symlink present: $s"
done

# ---------------------------------------------------------------------------
# Stop hook merged into settings.json without clobbering existing config.
# ---------------------------------------------------------------------------
SETTINGS="$FAKE_HOME/.claude/settings.json"
assert_file "$SETTINGS" "settings.json still present"
assert_json_valid "$SETTINGS" "settings.json still valid JSON after merge"

# Count Stop hooks that wrap our hooks/stop-save.sh. Fingerprint on the script
# name, not the repo dir name — checkouts are often lowercase, and a user's
# unrelated pre-existing hooks may mention "2ndbrain".
COUNT_2B_STOP=0
if command -v jq >/dev/null 2>&1; then
  COUNT_2B_STOP=$(jq '
    [ .hooks.Stop[]?
      | .hooks[]?
      | select(.command | test("hooks/stop-save\\.sh"; "i"))
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
# The user reads the README guide and deletes it, as it tells them to.
rm -f "$FAKE_VAULT/README.md"

SECOND_OUT="$(run_install || true)"
SECOND_RC=$?
assert_eq "$SECOND_RC" "0" "install.sh exits 0 on second run (idempotent)"
[[ "${VERBOSE:-0}" == "1" ]] && printf '%s\n' "$SECOND_OUT"

# Stop hook count still 1, not duplicated.
COUNT_2B_STOP2=0
if command -v jq >/dev/null 2>&1; then
  COUNT_2B_STOP2=$(jq '
    [ .hooks.Stop[]?
      | .hooks[]?
      | select(.command | test("hooks/stop-save\\.sh"; "i"))
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
for d in 01-Projects 02-Library 03-Index 04-Tasks Claude-Memory; do
  assert_dir "$FAKE_VAULT/$d" "folder still present after re-install: $d"
done

# A deleted README stays deleted: the guide only goes into a brand-new vault.
if [[ -e "$FAKE_VAULT/README.md" ]]; then _fail "README.md came back after the user deleted it"; else _pass "deleted README.md stays deleted on re-install"; fi

assert_report
