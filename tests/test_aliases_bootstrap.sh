#!/usr/bin/env bash
# tests/test_aliases_bootstrap.sh
# /aliases --bootstrap creates an aliases.yaml scaffold if absent,
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
    rm -rf "$TMPROOT"
  fi
}
trap cleanup EXIT

VAULT="$TMPROOT/vault"
cp -R "$HERE/fixtures/sample-vault/." "$VAULT/"

ALIAS_CMD=""
for candidate in \
  "$REPO_ROOT/skills/aliases/run.sh" \
  "$REPO_ROOT/skills/aliases/aliases" \
  "$REPO_ROOT/bin/aliases" \
  "$REPO_ROOT/scripts/aliases.sh"
do
  if [[ -x "$candidate" ]]; then ALIAS_CMD="$candidate"; break; fi
done

if [[ -z "$ALIAS_CMD" ]]; then
  printf "%sSKIP%s test_aliases_bootstrap (no aliases command found)\n" \
    "${_C_YELLOW:-}" "${_C_RESET:-}"
  exit 0
fi

ALIASES_YAML="$VAULT/04-Index/aliases.yaml"

# ---------------------------------------------------------------------------
# Case 1: absent -> --bootstrap creates scaffold.
# ---------------------------------------------------------------------------
rm -f "$ALIASES_YAML"
VAULT_DIR="$VAULT" "$ALIAS_CMD" --bootstrap </dev/null >/dev/null 2>&1 || true

assert_file "$ALIASES_YAML" "aliases.yaml created on --bootstrap"
assert_contains "$ALIASES_YAML" "aliases:" "aliases.yaml contains 'aliases:' root key"

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

# ---------------------------------------------------------------------------
# Case 2: existing customized file is preserved verbatim.
# ---------------------------------------------------------------------------
CUSTOM_CONTENT='aliases:
  nate: ["Nathan", "nate"]
  lorecraft: ["Lorecraft LLC", "lorecraft-io"]
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
assert_contains "$ALIASES_YAML" "lorecraft:" \
  "user-defined alias entry preserved"

assert_report
