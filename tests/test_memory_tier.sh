#!/usr/bin/env bash
# tests/test_memory_tier.sh
# The opt-in memory tier: decay, promotion, and what was true when. Runs bin/memory
# on a temp vault with a fixed --today, and the installer against a temp home.

set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/.." && pwd)"
# shellcheck source=./lib/assertions.sh
source "$HERE/lib/assertions.sh"

assert_reset "test_memory_tier"

TMPROOT="$(mktemp -d -t 2brain-memory-XXXXXX)"
cleanup() {
  if [[ -n "${TMPROOT:-}" && ( "$TMPROOT" == /tmp/* || "$TMPROOT" == /var/folders/* ) ]]; then
    rm -rf "${TMPROOT:?}"
  fi
}
trap cleanup EXIT

export HOME="$TMPROOT/home"
export CLAUDE_HOME="$HOME/.claude"
mkdir -p "$CLAUDE_HOME"
VAULT="$HOME/vault"
mkdir -p "$VAULT"
cp -R "$HERE/fixtures/sample-vault/." "$VAULT/"
MEM="$REPO_ROOT/bin/memory"
TODAY="2026-11-01"
assert_file "$MEM" "bin/memory exists"

mem() { VAULT_DIR="$VAULT" "$MEM" "$@" --today "$TODAY"; }

note() { # path owner seen [extra frontmatter line]
  mkdir -p "$(dirname "$VAULT/$1")"
  {
    printf -- '---\ntitle: "%s"\ndate: 2026-01-01\ntype: concept\n' "$(basename "$1" .md)"
    [[ -n "$2" ]] && printf 'owner: %s\n' "$2"
    [[ -n "$3" ]] && printf 'last_confirmed: %s\n' "$3"
    [[ -n "${4:-}" ]] && printf '%s\n' "$4"
    printf -- '---\n\nThe body stays byte for byte.\n\nA second --- line in the body:\n---\nowner: human\n'
  } > "$VAULT/$1"
}
body_of() { awk 'NR==1{next} !d && /^---/{d=1; next} d' "$1"; }
fm_of() { awk 'NR==1{next} /^---/{exit} {print}' "$1"; }

# ---------------------------------------------------------------------------
# Opt-in: without the config the tier refuses, read-only commands included.
# ---------------------------------------------------------------------------
mem status >/dev/null 2>&1
assert_eq "$?" "4" "status exits 4 when the tier is off"
mem decay --apply >/dev/null 2>&1
assert_eq "$?" "4" "decay --apply exits 4 when the tier is off"

cp "$REPO_ROOT/vault-template/Claude-Memory/memory-tier.example.yaml" "$VAULT/Claude-Memory/memory-tier.yaml"

# ---------------------------------------------------------------------------
# Fixtures. Today is 2026-11-01: 60 days back is 09-02, 180 back is 05-05, 540 back
# is 2025-05-10.
# ---------------------------------------------------------------------------
note 02-Library/ideas/fresh.md            wiki  2026-10-20
note 02-Library/ideas/edge-fresh.md       wiki  2026-09-02
note 02-Library/ideas/edge-stale.md       wiki  2026-09-01
note 02-Library/ideas/stale.md            llm   2026-07-01
note 02-Library/ideas/decayed.md          wiki  2026-01-15
note 02-Library/ideas/durable-ok.md       wiki  2026-07-01 "durability: durable"
note 02-Library/ideas/durable-stale.md    wiki  2026-01-15 "durability: durable"
note 02-Library/ideas/foundational.md     wiki  2020-01-01 "durability: foundational"
note 02-Library/ideas/human-old.md        human 2026-01-15
note 02-Library/ideas/no-owner-old.md     ""    2026-01-15
note 02-Library/ideas/seenat-wins.md      wiki  2026-01-15 "seenat: 2026-10-30"
cat > "$VAULT/02-Library/ideas/undated.md" <<'EOF'
---
title: "undated"
type: concept
owner: wiki
---
no dates at all
EOF
# Records can't go stale, whatever their age.
cat > "$VAULT/02-Library/sources/SRC-old.md" <<'EOF'
---
title: "old source"
date: 2020-01-01
type: source
owner: wiki
---
a capture of what an article said
EOF
cat > "$VAULT/02-Library/ideas/a-source-in-the-wrong-place.md" <<'EOF'
---
title: "misfiled"
date: 2020-01-01
type: source
owner: wiki
---
still a record
EOF
# The sync's files are never in scope, wherever they sit.
cp "$HERE/fixtures/tasks/before.md" "$VAULT/04-Tasks/TASKS-SAMPLE.md"
TASKS_MD5="$(md5_of "$VAULT/04-Tasks/TASKS-SAMPLE.md")"

state_of() { mem list --state "$2" 2>/dev/null | grep -qxF "02-Library/ideas/$1.md"; }
expect_state() {
  if state_of "$1" "$2"; then _pass "$1 is $2"; else _fail "$1 should be $2"; fi
}

# ---------------------------------------------------------------------------
# The date rule, including its edges.
# ---------------------------------------------------------------------------
expect_state fresh fresh
expect_state edge-fresh fresh          # exactly 60 days
expect_state edge-stale stale          # 61 days
expect_state stale stale
expect_state decayed decayed
expect_state durable-ok fresh          # 123 days, inside the durable window
expect_state durable-stale stale       # 290 days, past durable's 180
expect_state foundational fresh        # never decays
expect_state seenat-wins fresh         # seenat newer than last_confirmed
expect_state undated undated

if mem list --state decayed | grep -q "a-source-in-the-wrong-place"; then
  _fail "a type: source note must never decay"
else
  _pass "a type: source note is out of scope, even in 02-Library/ideas/"
fi
mem list --state nonsense >/dev/null 2>&1
assert_eq "$?" "2" "an unknown state is a usage error"

# Across a leap day: 2028-02-28 to 2028-04-28 is 60 days, and 04-29 is 61.
note 02-Library/ideas/leap.md wiki 2028-02-28
VAULT_DIR="$VAULT" "$MEM" list --state fresh --today 2028-04-28 | grep -q "leap.md"
assert_eq "$?" "0" "60 days across a leap day is still fresh"
VAULT_DIR="$VAULT" "$MEM" list --state stale --today 2028-04-29 | grep -q "leap.md"
assert_eq "$?" "0" "61 days across a leap day is stale"
rm -f "${VAULT:?}/02-Library/ideas/leap.md"

# ---------------------------------------------------------------------------
# status is read-only.
# ---------------------------------------------------------------------------
SNAP="$TMPROOT/snap"
snapshot_dir "$VAULT" > "$SNAP.1"
STATUS_OUT="$(mem status)"
assert_eq "$?" "0" "status exits 0"
snapshot_dir "$VAULT" > "$SNAP.2"
if diff -q "$SNAP.1" "$SNAP.2" >/dev/null; then _pass "status changes nothing"; else _fail "status changed the vault"; fi
if printf '%s' "$STATUS_OUT" | grep -q "02-Library/ideas/decayed.md: last seen 2026-01-15, 290 days ago"; then
  _pass "status names the note, the date and the age"
else
  _fail "status output: $STATUS_OUT"
fi

# ---------------------------------------------------------------------------
# decay: dry run first, then --apply.
# ---------------------------------------------------------------------------
DRY="$(mem decay)"
assert_eq "$?" "0" "decay dry run exits 0"
snapshot_dir "$VAULT" > "$SNAP.3"
if diff -q "$SNAP.1" "$SNAP.3" >/dev/null; then _pass "decay without --apply writes nothing"; else _fail "decay dry run wrote"; fi
if printf '%s' "$DRY" | grep -q "would: 02-Library/ideas/stale.md"; then _pass "dry run says what it would do"; else _fail "dry run output: $DRY"; fi
if printf '%s' "$DRY" | grep -q "propose: 02-Library/ideas/human-old.md"; then _pass "owner: human gets a proposal"; else _fail "no proposal for human note"; fi
if printf '%s' "$DRY" | grep -q "propose: 02-Library/ideas/no-owner-old.md"; then _pass "a note with no owner gets a proposal"; else _fail "no proposal for unowned note"; fi

BODY_BEFORE="$(body_of "$VAULT/02-Library/ideas/stale.md")"
HUMAN_MD5="$(md5_of "$VAULT/02-Library/ideas/human-old.md")"
NOOWNER_MD5="$(md5_of "$VAULT/02-Library/ideas/no-owner-old.md")"
FRESH_MD5="$(md5_of "$VAULT/02-Library/ideas/fresh.md")"
FOUNDATIONAL_MD5="$(md5_of "$VAULT/02-Library/ideas/foundational.md")"

mem decay --apply >/dev/null
assert_eq "$?" "0" "decay --apply exits 0"

assert_contains "$VAULT/02-Library/ideas/stale.md" "memory_state: stale" "stale note marked"
assert_contains "$VAULT/02-Library/ideas/stale.md" "needs_review: true" "stale note flagged for review"
assert_contains "$VAULT/02-Library/ideas/decayed.md" "memory_state: decayed" "decayed note marked"
assert_contains "$VAULT/02-Library/ideas/durable-stale.md" "memory_state: stale" "durable note past its window marked stale"
assert_eq "$(body_of "$VAULT/02-Library/ideas/stale.md")" "$BODY_BEFORE" "the body is byte-for-byte unchanged"
if fm_of "$VAULT/02-Library/ideas/stale.md" | grep -q "^owner: llm$"; then _pass "other frontmatter kept"; else _fail "frontmatter damaged"; fi

assert_eq "$(md5_of "$VAULT/02-Library/ideas/human-old.md")" "$HUMAN_MD5" "owner: human note untouched"
assert_eq "$(md5_of "$VAULT/02-Library/ideas/no-owner-old.md")" "$NOOWNER_MD5" "unowned note untouched"
assert_eq "$(md5_of "$VAULT/02-Library/ideas/fresh.md")" "$FRESH_MD5" "fresh note untouched"
assert_eq "$(md5_of "$VAULT/02-Library/ideas/foundational.md")" "$FOUNDATIONAL_MD5" "foundational note untouched"
assert_eq "$(md5_of "$VAULT/04-Tasks/TASKS-SAMPLE.md")" "$TASKS_MD5" "04-Tasks/ untouched"
assert_not_contains "$VAULT/02-Library/sources/SRC-old.md" "memory_state" "source note untouched"

BACKUPS="$(find "$VAULT/Claude-Memory/backups" -type f -name '*stale.md.bak' | wc -l | tr -d ' ')"
if [[ "$BACKUPS" -ge 1 ]]; then _pass "a backup was taken before the rewrite"; else _fail "no backup taken"; fi

# Running it again finds nothing new to do.
SECOND="$(mem decay --apply | grep -v '^propose:')"
assert_eq "$SECOND" "" "decay is idempotent"

# ---------------------------------------------------------------------------
# confirm brings a note back, and decay then clears the mark on its own.
# ---------------------------------------------------------------------------
mem confirm 02-Library/ideas/decayed.md >/dev/null
assert_contains "$VAULT/02-Library/ideas/decayed.md" "memory_state: decayed" "confirm without --apply writes nothing"
mem confirm 02-Library/ideas/decayed.md --apply >/dev/null
assert_eq "$?" "0" "confirm --apply exits 0"
assert_contains "$VAULT/02-Library/ideas/decayed.md" "seenat: $TODAY" "confirm stamps seenat"
assert_contains "$VAULT/02-Library/ideas/decayed.md" "last_confirmed: $TODAY" "confirm stamps last_confirmed"
assert_not_contains "$VAULT/02-Library/ideas/decayed.md" "memory_state" "confirm clears the mark"
expect_state decayed fresh

# A note confirmed by hand, with the mark still on it.
sed -e "s/^last_confirmed: .*/last_confirmed: $TODAY/" "$VAULT/02-Library/ideas/stale.md" > "$TMPROOT/s.md"
cp "$TMPROOT/s.md" "$VAULT/02-Library/ideas/stale.md"
mem decay --apply >/dev/null
assert_not_contains "$VAULT/02-Library/ideas/stale.md" "memory_state" "decay clears the mark once a note is seen again"

# ---------------------------------------------------------------------------
# The regimes hold for direct commands too.
# ---------------------------------------------------------------------------
mem confirm 02-Library/ideas/human-old.md --apply >/dev/null 2>&1
assert_eq "$?" "3" "confirm refuses an owner: human note"
assert_eq "$(md5_of "$VAULT/02-Library/ideas/human-old.md")" "$HUMAN_MD5" "and leaves it alone"
mem confirm 02-Library/ideas/no-owner-old.md --apply >/dev/null 2>&1
assert_eq "$?" "3" "confirm refuses a note with no owner"
mem confirm 04-Tasks/TASKS-SAMPLE.md --apply >/dev/null 2>&1
assert_eq "$?" "3" "confirm refuses 04-Tasks/"
mem record 04-Tasks/TASKS-SAMPLE.md --claim x --apply >/dev/null 2>&1
assert_eq "$?" "3" "record refuses 04-Tasks/"
mem confirm "02-Library/ideas/../04-Tasks/TASKS-SAMPLE.md" --apply >/dev/null 2>&1
assert_eq "$?" "3" "confirm refuses a path with .. in it"
mem confirm "$TMPROOT/outside.md" --apply >/dev/null 2>&1
assert_eq "$?" "3" "confirm refuses a path outside the vault"
mem confirm 02-Library/ideas/not-there.md --apply >/dev/null 2>&1
assert_eq "$?" "2" "confirm on a missing note is a usage error"
assert_eq "$(md5_of "$VAULT/04-Tasks/TASKS-SAMPLE.md")" "$TASKS_MD5" "04-Tasks/ still untouched"

# ---------------------------------------------------------------------------
# promote: held for long enough AND linked from enough notes. Both are required.
# ---------------------------------------------------------------------------
mkdir -p "$VAULT/02-Library/sources"
note 02-Library/ideas/held-up.md        wiki  2026-10-25 "asof: 2026-03-01"
note 02-Library/ideas/held-unlinked.md  wiki  2026-10-25 "asof: 2026-03-01"
note 02-Library/ideas/new-but-linked.md wiki  2026-10-25 "asof: 2026-10-01"
note 02-Library/ideas/human-held.md     human 2026-10-25 "asof: 2026-03-01"
for i in 1 2 3; do
  printf 'see [[held-up]] and [[Held-Up|again]] and [[new-but-linked#a-heading]] and [[human-held]]\n' > "$VAULT/02-Library/sources/linker-$i.md"
done
printf 'I link to myself: [[held-unlinked]] [[held-unlinked]] [[held-unlinked]]\n' >> "$VAULT/02-Library/ideas/held-unlinked.md"

PROMO="$(mem promote)"
if printf '%s' "$PROMO" | grep -q "would: 02-Library/ideas/held-up.md: durable, held for 238 days with 3 inbound links"; then
  _pass "promote names what qualifies and why"
else
  _fail "promote output: $PROMO"
fi
assert_not_contains "$VAULT/02-Library/ideas/held-up.md" "durability" "promote without --apply writes nothing"
if printf '%s' "$PROMO" | grep -q "held-unlinked"; then _fail "self-links must not count as inbound"; else _pass "self-links don't count"; fi
if printf '%s' "$PROMO" | grep -q "new-but-linked"; then _fail "a young note must not promote"; else _pass "a young note doesn't promote, however linked"; fi
if printf '%s' "$PROMO" | grep -q "propose: 02-Library/ideas/human-held.md"; then _pass "owner: human gets a proposal"; else _fail "no proposal for human note"; fi

HUMAN_HELD_MD5="$(md5_of "$VAULT/02-Library/ideas/human-held.md")"
mem promote --apply >/dev/null
assert_contains "$VAULT/02-Library/ideas/held-up.md" "durability: durable" "promote --apply marks it durable"
assert_eq "$(md5_of "$VAULT/02-Library/ideas/human-held.md")" "$HUMAN_HELD_MD5" "owner: human note untouched"
expect_state held-up fresh
if mem promote | grep -q "held-up"; then _fail "a durable note promoted twice"; else _pass "promote is idempotent"; fi
if mem promote | grep -q "foundational"; then _fail "promote must never reach foundational"; else _pass "foundational is only ever set by a human"; fi

# ---------------------------------------------------------------------------
# What was true when.
# ---------------------------------------------------------------------------
note 02-Library/ideas/morgen.md wiki 2026-04-14
N=02-Library/ideas/morgen.md

mem record "$N" --claim 'Morgen MCP is at v0.1.7' --asof 2026-04-14 >/dev/null
assert_not_contains "$VAULT/$N" "bi-temporal" "record without --apply writes nothing"

mem record "$N" --claim 'Morgen MCP is at v0.1.7' --asof 2026-04-14 --apply >/dev/null
assert_eq "$?" "0" "record --apply exits 0"
assert_contains "$VAULT/$N" 'claim: "Morgen MCP is at v0.1.7"' "claim recorded"
assert_contains "$VAULT/$N" "recorded: $TODAY" "the day it was written down is kept"

mem record "$N" --claim 'Morgen MCP is at v0.2.0' --asof 2026-06-20 --replaces 'Morgen MCP is at v0.1.7' --apply >/dev/null
assert_eq "$?" "0" "record --replaces exits 0"
assert_contains "$VAULT/$N" "until: 2026-06-20" "the replaced claim is closed on the day the delta landed"
assert_contains "$VAULT/$N" "The body stays byte for byte." "body kept"

mem record "$N" --claim 'x' --replaces 'a claim that is not there' --apply >/dev/null 2>&1
assert_eq "$?" "3" "record refuses to replace a claim that isn't there"

mem record "$N" --claim 'She said "hi" \ there' --asof 2026-10-01 --apply >/dev/null
assert_contains "$VAULT/$N" 'claim: "She said \"hi\" \\ there"' "quotes and backslashes are escaped"

FAKE_KEY="sk-ant-""abcdefghijklmnopqrstuvwxyz012345"
mem record "$N" --claim "the key is $FAKE_KEY" --apply >/dev/null 2>&1
assert_eq "$?" "3" "record refuses a claim holding a secret"
assert_not_contains "$VAULT/$N" "sk-ant-" "the secret did not land"

mem when 2026-05-01 --note "$N" > "$TMPROOT/when1"
assert_contains "$TMPROOT/when1" "v0.1.7" "on 05-01 the old claim was true"
assert_not_contains "$TMPROOT/when1" "v0.2.0" "on 05-01 the new claim wasn't yet"

mem when 2026-07-01 --note "$N" > "$TMPROOT/when2"
assert_contains "$TMPROOT/when2" "v0.2.0" "on 07-01 the new claim was true"
assert_not_contains "$TMPROOT/when2" "v0.1.7" "on 07-01 the old claim wasn't any more"

mem when 2026-06-20 --note "$N" > "$TMPROOT/when3"
assert_contains "$TMPROOT/when3" "v0.2.0" "the day the delta landed goes to the new claim"
assert_not_contains "$TMPROOT/when3" "v0.1.7" "and not the old one"

mem when 2026-01-01 --note "$N" > "$TMPROOT/when4"
assert_contains "$TMPROOT/when4" "Nothing in the vault" "before any claim, it says so"

# A note with no claim list answers with its one date.
note 02-Library/ideas/plain.md wiki 2026-10-01 "asof: 2026-02-01"
mem when 2026-03-01 --note 02-Library/ideas/plain.md > "$TMPROOT/when5"
assert_contains "$TMPROOT/when5" "whole note, as of 2026-02-01" "a plain note answers at the note level"
mem when 2026-01-15 --note 02-Library/ideas/plain.md > "$TMPROOT/when6"
assert_contains "$TMPROOT/when6" "Nothing in the vault" "and not before its date"

# Across the whole vault, reading owner: human notes is fine.
mem when 2026-05-01 > "$TMPROOT/when7"
assert_contains "$TMPROOT/when7" "02-Library/ideas/human-old.md" "when reads human-owned notes"
mem when not-a-date >/dev/null 2>&1
assert_eq "$?" "2" "when rejects a bad date"

# Dates and config are validated at the door.
VAULT_DIR="$VAULT" "$MEM" status --today 2026-13-40 >/dev/null 2>&1
assert_eq "$?" "2" "a bad --today is a usage error"

# Config changes the rule.
printf 'stale_days: 400\ndecay_days: 900\n' > "$VAULT/Claude-Memory/memory-tier.yaml"
expect_state durable-stale fresh

# ---------------------------------------------------------------------------
# The installer: off by default, on with the flag, and it never clobbers.
# ---------------------------------------------------------------------------
IVAULT="$HOME/ivault"
mkdir -p "$IVAULT"
run_install() {
  VAULT_DIR="$IVAULT" bash "$REPO_ROOT/install.sh" --vault "$IVAULT" --apply \
    --no-launchd --no-obsidian-app --no-obsidian-mcp --no-statusline-brain \
    --no-shell-shortcuts --no-skill-packs --skip-tests "$@" >/dev/null 2>&1
}
run_install
if [[ -e "$IVAULT/Claude-Memory/memory-tier.yaml" ]]; then
  _fail "default install turned the tier on"
else
  _pass "default install leaves the tier off"
fi
run_install --with-memory
assert_file "$IVAULT/Claude-Memory/memory-tier.yaml" "--with-memory writes the config"
VAULT_DIR="$IVAULT" "$MEM" status >/dev/null 2>&1
assert_eq "$?" "0" "the tier runs on an installed vault"
printf 'stale_days: 7\n' > "$IVAULT/Claude-Memory/memory-tier.yaml"
run_install --with-memory
assert_contains "$IVAULT/Claude-Memory/memory-tier.yaml" "stale_days: 7" "re-install keeps my thresholds"

# A legacy 03-Concepts/ is retired: never scanned or written, and status says so.
note 03-Concepts/legacy-decayed.md wiki 2026-01-15
LEGACY_MD5="$(md5_of "$VAULT/03-Concepts/legacy-decayed.md")"
LEGACY_OUT="$(mem status)"
if printf '%s' "$LEGACY_OUT" | grep -q "03-Concepts/legacy-decayed.md"; then _fail "status scanned the retired 03-Concepts/"; else _pass "status skips the retired 03-Concepts/"; fi
if printf '%s' "$LEGACY_OUT" | grep -q "03-Concepts/ is a retired folder"; then _pass "status points at the migration"; else _fail "no retired-folder note: $LEGACY_OUT"; fi
mem decay --apply >/dev/null 2>&1
assert_eq "$(md5_of "$VAULT/03-Concepts/legacy-decayed.md")" "$LEGACY_MD5" "decay --apply leaves the retired 03-Concepts/ alone"
mem confirm 03-Concepts/legacy-decayed.md --apply >/dev/null 2>&1
assert_eq "$?" "3" "confirm refuses a note in a retired folder"

assert_report
