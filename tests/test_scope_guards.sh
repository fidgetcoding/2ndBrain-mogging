#!/usr/bin/env bash
# tests/test_scope_guards.sh
# /wiki refuses to write into 05-Tasks/.
# - attempt --target 05-Tasks/INJECTED.md -> rc != 0, TASKS files unchanged
# - no INJECTED.md exists anywhere in the vault
# - writing into 02-Library/sources still works (positive control)
# Plus the ways around it: traversal, symlinks, case, absolute paths, and the other
# regimes a skill must not rewrite, including the retired folders (02-Sources/ and
# 03-Concepts/ since Library v2). Runs bin/wiki and hooks/vault-guard.sh.

set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/.." && pwd)"
# shellcheck source=./lib/assertions.sh
source "$HERE/lib/assertions.sh"

assert_reset "test_scope_guards"

TMPROOT="$(mktemp -d -t 2brain-scope-XXXXXX)"
cleanup() {
  if [[ -n "${TMPROOT:-}" && ( "$TMPROOT" == /tmp/* || "$TMPROOT" == /var/folders/* ) ]]; then
    rm -rf "${TMPROOT:?}"
  fi
}
trap cleanup EXIT

VAULT="$TMPROOT/vault"
cp -R "$HERE/fixtures/sample-vault/." "$VAULT/"
cp "$HERE/fixtures/tasks/before.md" "$VAULT/05-Tasks/TASKS-SAMPLE.md"
export HOME="$TMPROOT/home"
unset CLAUDE_HOME
mkdir -p "$HOME/.claude"

WIKI_CMD="$REPO_ROOT/bin/wiki"
GUARD="$REPO_ROOT/hooks/vault-guard.sh"
assert_file "$WIKI_CMD" "bin/wiki exists"
assert_file "$GUARD" "hooks/vault-guard.sh exists"

# ---------------------------------------------------------------------------
# Snapshot the 05-Tasks directory BEFORE any wiki invocation.
# ---------------------------------------------------------------------------
TASKS_BEFORE_SNAP="$TMPROOT/tasks.before"
snapshot_dir "$VAULT/05-Tasks" > "$TASKS_BEFORE_SNAP"

# ---------------------------------------------------------------------------
# Attempt forbidden target: 05-Tasks/INJECTED.md
# Expect non-zero return code.
# ---------------------------------------------------------------------------
FORBIDDEN_REL="05-Tasks/INJECTED.md"

VAULT_DIR="$VAULT" "$WIKI_CMD" add \
  --title "injected" \
  --body  "attacker payload" \
  --target "$FORBIDDEN_REL" \
  --yes </dev/null >/dev/null 2>&1
RC=$?

if [[ $RC -ne 0 ]]; then
  _pass "wiki returned non-zero on forbidden target ($FORBIDDEN_REL)"
else
  _fail "wiki returned 0 on forbidden target ($FORBIDDEN_REL)"
fi

# Each of these resolves into 05-Tasks/ or out of the vault. None may land.
ln -s "$VAULT/05-Tasks" "$VAULT/02-Library/sources/tasks-link"
ln -s "$VAULT/05-Tasks/TASKS-SAMPLE.md" "$VAULT/02-Library/sources/file-link.md"
for sneaky in \
  "02-Library/sources/../05-Tasks/INJECTED.md" \
  "02-Library/sources/tasks-link/INJECTED.md" \
  "02-Library/sources/file-link.md" \
  "05-tasks/INJECTED.md" \
  "$VAULT/05-Tasks/INJECTED.md" \
  "../INJECTED.md" \
  "$TMPROOT/INJECTED.md"
do
  VAULT_DIR="$VAULT" "$WIKI_CMD" add --title "injected" --body "payload" --target "$sneaky" --yes </dev/null >/dev/null 2>&1
  assert_eq "$?" "3" "wiki add refuses $sneaky"
  VAULT_DIR="$VAULT" "$WIKI_CMD" check --target "$sneaky" </dev/null >/dev/null 2>&1
  assert_eq "$?" "3" "wiki check refuses $sneaky"
done

# The INJECTED.md file must not exist anywhere in the vault.
INJECTED_HITS="$(find "$TMPROOT" -type f -name 'INJECTED.md' | wc -l | tr -d ' ')"
assert_eq "$INJECTED_HITS" "0" "no INJECTED.md anywhere in vault"

# 05-Tasks snapshot unchanged.
TASKS_AFTER_SNAP="$TMPROOT/tasks.after"
snapshot_dir "$VAULT/05-Tasks" > "$TASKS_AFTER_SNAP"

if diff -q "$TASKS_BEFORE_SNAP" "$TASKS_AFTER_SNAP" >/dev/null; then
  _pass "05-Tasks/ byte-identical after forbidden wiki attempt"
else
  _fail "05-Tasks/ changed despite scope-guard rejection"
  diff "$TASKS_BEFORE_SNAP" "$TASKS_AFTER_SNAP" 1>&2 || true
fi

# Specifically the fixture's TASKS-SAMPLE.md must be unchanged.
SAMPLE="$VAULT/05-Tasks/TASKS-SAMPLE.md"
assert_eq "$(md5_of "$SAMPLE")" "$(md5_of "$HERE/fixtures/tasks/before.md")" "TASKS-SAMPLE.md unchanged"

# ---------------------------------------------------------------------------
# The other regimes /wiki must not write.
# ---------------------------------------------------------------------------
mkdir -p "$VAULT/01-Projects/ACME"
printf '# ACME\n' > "$VAULT/01-Projects/ACME/ACME.md"
printf -- '---\ntitle: "Mine"\nowner: human\n---\nmy words\n' > "$VAULT/02-Library/ideas/mine.md"
printf -- '---\ntitle: "Compiled"\nowner: wiki\n---\ncompiled\n' > "$VAULT/02-Library/ideas/compiled.md"

for refused in 01-Projects/ACME/ACME.md 02-Library/ideas/mine.md .env .env.local CLAUDE.md .git/config node_modules/x/y.md; do
  VAULT_DIR="$VAULT" "$WIKI_CMD" check --target "$refused" </dev/null >/dev/null 2>&1
  assert_eq "$?" "3" "wiki check refuses $refused"
done
for allowed in 01-Projects/ACME/notes.md 02-Library/ideas/compiled.md 02-Library/ideas/new.md 04-Index/Tech-Index.md; do
  VAULT_DIR="$VAULT" "$WIKI_CMD" check --target "$allowed" </dev/null >/dev/null 2>&1
  assert_eq "$?" "0" "wiki check allows $allowed"
done

# Retired folders (Library v2): a legacy vault may still have them, nothing writes there.
mkdir -p "$VAULT/02-Sources" "$VAULT/03-Concepts"
for retired in 02-Sources/SRC-2026-11-05-x.md 03-Concepts/x.md 02-sources/x.md 00-Inbox/x.md 02-Literature/x.md 04-MOC/x.md; do
  VAULT_DIR="$VAULT" "$WIKI_CMD" check --target "$retired" </dev/null >/dev/null 2>&1
  assert_eq "$?" "3" "wiki check refuses retired $retired"
done
RETIRED_OUT="$(VAULT_DIR="$VAULT" "$WIKI_CMD" add --title x --body y --target 03-Concepts/x.md --yes </dev/null 2>&1)"
assert_eq "$?" "3" "wiki add refuses a retired folder"
if printf '%s' "$RETIRED_OUT" | grep -q "02-Library/ideas/"; then _pass "the refusal names the new home"; else _fail "retired refusal: $RETIRED_OUT"; fi
if [[ -e "$VAULT/03-Concepts/x.md" ]]; then _fail "a note landed in 03-Concepts/"; else _pass "nothing landed in 03-Concepts/"; fi
for allowed in 02-Library/people/ada.md 02-Library/tools/obsidian.md 02-Library/sources/SRC-2026-11-05-x.md 01-Projects/ACME/notes/SRC-2026-11-05-y.md; do
  VAULT_DIR="$VAULT" "$WIKI_CMD" check --target "$allowed" </dev/null >/dev/null 2>&1
  assert_eq "$?" "0" "wiki check allows $allowed"
done

# add with no --target files a source under 02-Library/sources/; people and tools
# are concepts with their tag.
VAULT_DIR="$VAULT" "$WIKI_CMD" add --title "Default Home" --body "where does it land" --yes </dev/null >/dev/null 2>&1
assert_eq "$?" "0" "wiki add with no --target succeeds"
DEFAULT_HIT="$(find "$VAULT/02-Library/sources" -name 'SRC-*-default-home.md' | head -n 1)"
if [[ -n "$DEFAULT_HIT" ]]; then
  _pass "default target is 02-Library/sources/SRC-<date>-<slug>.md"
  assert_contains "$DEFAULT_HIT" "type: source" "default note is a source"
else
  _fail "no default note under 02-Library/sources/"
fi
VAULT_DIR="$VAULT" "$WIKI_CMD" add --title "Ada" --body "a person" --target 02-Library/people/ada.md --yes </dev/null >/dev/null 2>&1
assert_contains "$VAULT/02-Library/people/ada.md" "type: concept" "a person note is a concept"
assert_contains "$VAULT/02-Library/people/ada.md" "tags: [person]" "a person note is tagged person"
VAULT_DIR="$VAULT" "$WIKI_CMD" add --title "Obsidian" --body "a tool" --target 02-Library/tools/obsidian.md --yes </dev/null >/dev/null 2>&1
assert_contains "$VAULT/02-Library/tools/obsidian.md" "tags: [tool]" "a tool note is tagged tool"
VAULT_DIR="$VAULT" "$WIKI_CMD" add --title "An idea" --body "an idea" --target 02-Library/ideas/an-idea.md --yes </dev/null >/dev/null 2>&1
assert_contains "$VAULT/02-Library/ideas/an-idea.md" "type: concept" "an idea note is a concept"

# add never overwrites, even in a regime it owns.
VAULT_DIR="$VAULT" "$WIKI_CMD" add --title x --body y --target 02-Library/ideas/compiled.md --yes </dev/null >/dev/null 2>&1
assert_eq "$?" "3" "wiki add refuses to overwrite an existing file"
assert_contains "$VAULT/02-Library/ideas/compiled.md" "compiled" "existing file left alone"

# The secret deny list applies to anything written through the gate. The fake key
# is split so the repo's own secret scanners don't flag this test file.
FAKE_KEY="sk-ant-""abcdefghijklmnopqrstuvwxyz012345"
VAULT_DIR="$VAULT" "$WIKI_CMD" add --title "leak" --body "key $FAKE_KEY" \
  --target 02-Library/sources/leak.md --yes </dev/null >/dev/null 2>&1
assert_eq "$?" "3" "wiki add refuses a body holding a secret"
if [[ -e "$VAULT/02-Library/sources/leak.md" ]]; then _fail "secret landed on disk"; else _pass "secret did not land on disk"; fi

# ---------------------------------------------------------------------------
# Positive control: writing to 02-Library/sources succeeds.
# ---------------------------------------------------------------------------
LEGAL_REL="02-Library/sources/LIT-legal-target.md"
rm -f "${VAULT:?}/${LEGAL_REL:?}"

VAULT_DIR="$VAULT" "$WIKI_CMD" add \
  --title "legal-target" \
  --body  "this is allowed" \
  --target "$LEGAL_REL" \
  --yes </dev/null >/dev/null 2>&1
RC2=$?

assert_eq "$RC2" "0" "wiki succeeds on legal target (02-Library/sources)"
assert_file "$VAULT/$LEGAL_REL" "legal-target file actually created"
assert_contains "$VAULT/$LEGAL_REL" "owner: wiki" "frontmatter carries owner"
assert_contains "$VAULT/$LEGAL_REL" "last_confirmed:" "frontmatter carries last_confirmed"

# ---------------------------------------------------------------------------
# The hook, as the /wiki and /autoresearch frontmatter register it.
# ---------------------------------------------------------------------------
wjson() { jq -n --arg f "$1" '{tool_name:"Write",tool_input:{file_path:$f,content:"x"}}'; }

wjson "$VAULT/05-Tasks/INJECTED.md" | "$GUARD" --skill wiki 2>/dev/null
assert_eq "$?" "0" "without the opt-in marker the hook does nothing"

printf '%s\n' "$VAULT" > "$HOME/.claude/.mogging-guard"

for skill in wiki autoresearch; do
  wjson "$VAULT/05-Tasks/INJECTED.md" | "$GUARD" --skill "$skill" 2>/dev/null
  assert_eq "$?" "2" "/$skill hook blocks a write into 05-Tasks/"
done
wjson "$VAULT/05-tasks/INJECTED.md" | "$GUARD" --skill wiki 2>/dev/null
assert_eq "$?" "2" "hook blocks the lowercase spelling too"
wjson "$VAULT/02-Library/sources/tasks-link/INJECTED.md" | "$GUARD" --skill wiki 2>/dev/null
assert_eq "$?" "2" "hook follows a symlinked folder into 05-Tasks/"
wjson "$VAULT/02-Library/sources/../05-Tasks/INJECTED.md" | "$GUARD" --skill wiki 2>/dev/null
assert_eq "$?" "2" "hook blocks a path with .. in it"
wjson "$VAULT/01-Projects/ACME/ACME.md" | "$GUARD" --skill wiki 2>/dev/null
assert_eq "$?" "2" "hook blocks a project index"
wjson "$VAULT/02-Library/ideas/mine.md" | "$GUARD" --skill wiki 2>/dev/null
assert_eq "$?" "2" "hook blocks an owner: human note"
wjson "$VAULT/02-Library/ideas/compiled.md" | "$GUARD" --skill wiki 2>/dev/null
assert_eq "$?" "0" "hook allows a wiki-owned note"
for skill in wiki autoresearch; do
  wjson "$VAULT/02-Sources/SRC-2026-11-05-z.md" | "$GUARD" --skill "$skill" 2>/dev/null
  assert_eq "$?" "2" "/$skill hook blocks a write into retired 02-Sources/"
  wjson "$VAULT/03-Concepts/z.md" | "$GUARD" --skill "$skill" 2>/dev/null
  assert_eq "$?" "2" "/$skill hook blocks a write into retired 03-Concepts/"
done
wjson "$TMPROOT/outside.md" | "$GUARD" --skill wiki 2>/dev/null
assert_eq "$?" "0" "hook ignores a file outside the vault"

# The command in each SKILL.md is what Claude Code actually runs. Pull it out and
# run it from a temp home with the skill symlinked in, the way install.sh does it.
fm_command() {
  awk 'NR>1 && /^---/{exit} /^ +command: /{sub(/^ +command: /,""); print}' "$REPO_ROOT/skills/$1/SKILL.md" \
    | jq -Rr 'fromjson? // .'
}
mkdir -p "$HOME/.claude/skills"
for skill in wiki autoresearch; do
  ln -s "$REPO_ROOT/skills/$skill" "$HOME/.claude/skills/$skill"
  cmd="$(fm_command "$skill")"
  if [[ -n "$cmd" ]]; then _pass "skills/$skill/SKILL.md declares the hook"; else _fail "skills/$skill/SKILL.md has no hook"; fi
  wjson "$VAULT/05-Tasks/INJECTED.md" | sh -c "$cmd" 2>/dev/null
  assert_eq "$?" "2" "/$skill frontmatter command blocks 05-Tasks/ from a real install layout"
done
# On a plugin install the path isn't there. That must stay silent, not error.
rm "${HOME:?}/.claude/skills/wiki"
cmd="$(fm_command wiki)"
wjson "$VAULT/05-Tasks/INJECTED.md" | sh -c "$cmd" 2>/dev/null
assert_eq "$?" "0" "frontmatter command stays quiet when the guard isn't on disk"

assert_report
