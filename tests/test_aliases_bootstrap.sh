#!/usr/bin/env bash
# tests/test_aliases_bootstrap.sh
# bin/aliases --bootstrap creates an aliases.yaml scaffold if absent,
# and NEVER overwrites an existing customized file.

set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/.." && pwd)"
# shellcheck source=./lib/assertions.sh
source "$HERE/lib/assertions.sh"

assert_reset "test_aliases_bootstrap"

TMPROOT="$(mktemp -d -t 2brain-alias-XXXXXX)"
cleanup() {
  if [[ -n "${TMPROOT:-}" && ( "$TMPROOT" == /tmp/* || "$TMPROOT" == /var/folders/* ) ]]; then
    rm -rf "${TMPROOT:?}"
  fi
}
trap cleanup EXIT

VAULT="$TMPROOT/vault"
cp -R "$HERE/fixtures/sample-vault/." "$VAULT/"

ALIAS_CMD="$REPO_ROOT/bin/aliases"
assert_file "$ALIAS_CMD" "bin/aliases exists"

# skills/aliases/SKILL.md is the contract: the file lives in Claude-Memory/.
ALIASES_YAML="$VAULT/Claude-Memory/aliases.yaml"
PENDING="$VAULT/Claude-Memory/aliases-pending.md"

# ---------------------------------------------------------------------------
# Case 1: absent -> --bootstrap creates scaffold.
# ---------------------------------------------------------------------------
rm -f "${ALIASES_YAML:?}"
VAULT_DIR="$VAULT" "$ALIAS_CMD" --bootstrap </dev/null >/dev/null 2>&1 || true

assert_file "$ALIASES_YAML" "aliases.yaml created on --bootstrap"
assert_contains "$ALIASES_YAML" "aliases:" "aliases.yaml contains 'aliases:' root key"
for key in "version: 1" "projects:" "people:" "concepts:" "orgs:"; do
  assert_contains "$ALIASES_YAML" "$key" "aliases.yaml has the schema's '$key'"
done

# Empty scaffold: either `aliases: {}` or `aliases:\n  ` (block-empty).
if grep -qE '^aliases:[[:space:]]*(\{\}|$)' "$ALIASES_YAML"; then
  _pass "aliases.yaml scaffold is empty (aliases: {} or block-empty)"
else
  # Soft-pass if the file is at least syntactically a stub — no nested entries.
  if ! grep -qE '^[[:space:]]+[A-Za-z0-9_-]+:' "$ALIASES_YAML"; then
    _pass "aliases.yaml scaffold has no pre-seeded entries"
  else
    _fail "aliases.yaml scaffold contains unexpected entries"
  fi
fi
if grep -qE '^[[:space:]]+[A-Za-z0-9_"-]+:' "$ALIASES_YAML"; then
  _fail "scaffold for a vault with no projects has entries"
else
  _pass "scaffold for a vault with no projects has no entries"
fi

# ---------------------------------------------------------------------------
# Case 2: existing customized file is preserved verbatim.
# ---------------------------------------------------------------------------
CUSTOM_CONTENT='aliases:
  operator: ["the operator", "operator"]
  <ORG-A>: ["<ORG-A>", "<ORG-A>"]
# user-custom-marker-do-not-remove
'
printf '%s' "$CUSTOM_CONTENT" > "$ALIASES_YAML"
BEFORE_MD5="$(md5_of "$ALIASES_YAML")"

VAULT_DIR="$VAULT" "$ALIAS_CMD" --bootstrap </dev/null >/dev/null 2>&1 || true

AFTER_MD5="$(md5_of "$ALIASES_YAML")"
assert_eq "$AFTER_MD5" "$BEFORE_MD5" \
  "existing aliases.yaml is byte-identical after --bootstrap (no clobber)"

assert_contains "$ALIASES_YAML" "user-custom-marker-do-not-remove" \
  "user comment preserved in aliases.yaml"
assert_contains "$ALIASES_YAML" "<ORG-A>:" \
  "user-defined alias entry preserved"
assert_file "$PENDING" "the proposal went to aliases-pending.md instead"

# ---------------------------------------------------------------------------
# Case 3: the folder scan. Direct children are projects. A deeper folder counts
# only with an index note named after itself, so content folders stay out.
# ---------------------------------------------------------------------------
rm -f "${ALIASES_YAML:?}" "${PENDING:?}"
mkdir -p "$VAULT/01-Projects/ACME/Website" "$VAULT/01-Projects/ACME/scratch" "$VAULT/01-Projects/SOLO"
: > "$VAULT/01-Projects/ACME/Website/Website.md"

VAULT_DIR="$VAULT" "$ALIAS_CMD" --bootstrap </dev/null >/dev/null 2>&1 || true

assert_contains "$ALIASES_YAML" 'path: "01-Projects/ACME"' "project folder scanned"
assert_contains "$ALIASES_YAML" 'path: "01-Projects/SOLO"' "second project folder scanned"
assert_contains "$ALIASES_YAML" 'path: "01-Projects/ACME/Website"' "sub-project with an index note scanned"
assert_not_contains "$ALIASES_YAML" "scratch" "folder without an index note left out"

# ---------------------------------------------------------------------------
# Case 4: no vault named, no write. It must never guess from the working dir.
# ---------------------------------------------------------------------------
( cd "$TMPROOT" && env -u VAULT_DIR "$ALIAS_CMD" --bootstrap </dev/null >/dev/null 2>&1 )
assert_eq "$?" "2" "--bootstrap with no vault exits 2"
if [[ -e "$TMPROOT/Claude-Memory" ]]; then _fail "wrote into the working directory"; else _pass "nothing written to the working directory"; fi

assert_report
