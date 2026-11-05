#!/usr/bin/env bash
# tests/test_migrate_to_library.sh
# scripts/migrate-to-library.sh moves a pre-2026-11-05 vault onto Library v2:
# 02-Sources/* -> 02-Library/sources/, 03-Concepts/* -> 02-Library/ideas/.
# - dry run by default: the vault stays byte-identical and no backup is written
# - --apply backs up first (~/WORK/<vault>-BACKUPS/), then moves, byte for byte
# - any name conflict refuses the whole run and moves nothing
# - 05-Tasks/ is never touched
# - empty legacy folders stay unless --remove-empty

set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/.." && pwd)"
# shellcheck source=./lib/assertions.sh
source "$HERE/lib/assertions.sh"

assert_reset "test_migrate_to_library"

TMPROOT="$(mktemp -d -t 2brain-migrate-XXXXXX)"
cleanup() {
  if [[ -n "${TMPROOT:-}" && ( "$TMPROOT" == /tmp/* || "$TMPROOT" == /var/folders/* ) ]]; then
    rm -rf "${TMPROOT:?}"
  fi
}
trap cleanup EXIT

export HOME="$TMPROOT/home"
mkdir -p "$HOME"
unset VAULT_DIR CLAUDE_HOME
MIGRATE="$REPO_ROOT/scripts/migrate-to-library.sh"
assert_file "$MIGRATE" "scripts/migrate-to-library.sh exists"

# A vault on the old layout, seeded the way install.sh used to seed it.
legacy_vault() {
  local v="$1"
  mkdir -p "$v/01-Projects/acme" "$v/02-Sources/clips" "$v/03-Concepts" "$v/04-Index" "$v/05-Tasks"
  touch "$v/02-Sources/.gitkeep" "$v/03-Concepts/.gitkeep"
  printf -- '---\ntitle: "acme"\ntype: project\n---\nSee [[idea-one]] and [[02-Sources/LIT-b|the old way]].\n' > "$v/01-Projects/acme/acme.md"
  printf -- '---\ntitle: "a"\ntype: source\n---\nsource a\n' > "$v/02-Sources/SRC-2026-01-01-a.md"
  printf -- '---\ntitle: "b"\ntype: source\n---\nsource b\n' > "$v/02-Sources/LIT-b.md"
  printf 'nested clip\n' > "$v/02-Sources/clips/c.md"
  printf -- '---\ntitle: "idea-one"\ntype: concept\nowner: human\n---\nFrom [[SRC-2026-01-01-a]].\n' > "$v/03-Concepts/idea-one.md"
  printf -- '---\ntitle: "Index"\ntype: index\n---\n- [[idea-one]]\n' > "$v/04-Index/Index.md"
  printf -- '- [ ] ship it 📅 2026-11-10 🆔 m-0a1b2c3d\n' > "$v/05-Tasks/TASKS-SAMPLE.md"
}

VAULT="$TMPROOT/vault"
legacy_vault "$VAULT"
BACKUPS="$HOME/WORK/vault-BACKUPS"
md5_a="$(md5_of "$VAULT/02-Sources/SRC-2026-01-01-a.md")"
md5_idea="$(md5_of "$VAULT/03-Concepts/idea-one.md")"
md5_clip="$(md5_of "$VAULT/02-Sources/clips/c.md")"
TASKS_BEFORE="$(snapshot_dir "$VAULT/05-Tasks")"

# ---------------------------------------------------------------------------
# Usage errors.
# ---------------------------------------------------------------------------
bash "$MIGRATE" >/dev/null 2>&1
assert_eq "$?" "2" "no vault and no marker exits 2"
bash "$MIGRATE" --vault "$VAULT" --bogus >/dev/null 2>&1
assert_eq "$?" "2" "an unknown flag exits 2"
bash "$MIGRATE" --vault "$TMPROOT/../x" >/dev/null 2>&1
assert_eq "$?" "2" "a vault path with .. exits 2"

# ---------------------------------------------------------------------------
# Dry run: says what it would do, changes nothing, writes no backup.
# ---------------------------------------------------------------------------
SNAP_BEFORE="$(snapshot_dir "$VAULT")"
DRY_RC=0
DRY_OUT="$(bash "$MIGRATE" --vault "$VAULT" 2>&1)" || DRY_RC=$?
assert_eq "$DRY_RC" "0" "dry run exits 0"
assert_eq "$(snapshot_dir "$VAULT")" "$SNAP_BEFORE" "dry run leaves the vault byte-identical"
if [[ -d "$VAULT/02-Library" ]]; then _fail "dry run created 02-Library/"; else _pass "dry run creates no folders"; fi
if [[ -e "$BACKUPS" ]]; then _fail "dry run wrote a backup"; else _pass "dry run writes no backup"; fi
for want in "02-Sources/SRC-2026-01-01-a.md  ->  02-Library/sources/SRC-2026-01-01-a.md" \
            "02-Sources/clips  ->  02-Library/sources/clips" \
            "03-Concepts/idea-one.md  ->  02-Library/ideas/idea-one.md" \
            "4 to move, 0 conflicting"; do
  if printf '%s' "$DRY_OUT" | grep -qF -- "$want"; then _pass "dry run lists: $want"; else _fail "dry run is missing: $want"; fi
done
if printf '%s' "$DRY_OUT" | grep -q '\.gitkeep'; then _fail "dry run plans to move .gitkeep"; else _pass "placeholders are not moved"; fi
if printf '%s' "$DRY_OUT" | grep -qF "01-Projects/acme/acme.md"; then
  _pass "dry run names the note with a path-style link"
else
  _fail "dry run missed the path-style link in acme.md"
fi

# ---------------------------------------------------------------------------
# A name conflict refuses everything: nothing moves, no backup.
# ---------------------------------------------------------------------------
CVAULT="$TMPROOT/conflict"
legacy_vault "$CVAULT"
mkdir -p "$CVAULT/02-Library/sources"
printf 'already here\n' > "$CVAULT/02-Library/sources/LIT-b.md"
C_SNAP="$(snapshot_dir "$CVAULT")"
C_RC=0
C_OUT="$(bash "$MIGRATE" --vault "$CVAULT" --apply 2>&1)" || C_RC=$?
assert_eq "$C_RC" "3" "a name conflict exits 3"
assert_eq "$(snapshot_dir "$CVAULT")" "$C_SNAP" "a conflict moves nothing"
if printf '%s' "$C_OUT" | grep -qF "02-Library/sources/LIT-b.md already exists"; then _pass "the conflict is named"; else _fail "conflict output: $C_OUT"; fi
if [[ -e "$HOME/WORK/conflict-BACKUPS" ]]; then _fail "a refused run wrote a backup"; else _pass "a refused run writes no backup"; fi

# A symlinked legacy folder is refused too.
SVAULT="$TMPROOT/symlinked"
mkdir -p "$SVAULT/elsewhere"
ln -s "$SVAULT/elsewhere" "$SVAULT/03-Concepts"
bash "$MIGRATE" --vault "$SVAULT" --apply >/dev/null 2>&1
assert_eq "$?" "3" "a symlinked 03-Concepts/ exits 3"

# ---------------------------------------------------------------------------
# --apply: backup first, then the move, byte for byte.
# ---------------------------------------------------------------------------
A_RC=0
A_OUT="$(bash "$MIGRATE" --vault "$VAULT" --apply 2>&1)" || A_RC=$?
assert_eq "$A_RC" "0" "--apply exits 0"
assert_file "$VAULT/02-Library/sources/SRC-2026-01-01-a.md" "SRC note moved to 02-Library/sources/"
assert_file "$VAULT/02-Library/sources/LIT-b.md" "LIT note moved to 02-Library/sources/"
assert_file "$VAULT/02-Library/sources/clips/c.md" "a subfolder moves with its contents"
assert_file "$VAULT/02-Library/ideas/idea-one.md" "concept moved to 02-Library/ideas/"
assert_dir "$VAULT/02-Library/people" "02-Library/people/ exists"
assert_dir "$VAULT/02-Library/tools" "02-Library/tools/ exists"
assert_eq "$(md5_of "$VAULT/02-Library/sources/SRC-2026-01-01-a.md")" "$md5_a" "source bytes unchanged"
assert_eq "$(md5_of "$VAULT/02-Library/ideas/idea-one.md")" "$md5_idea" "owner: human idea bytes unchanged"
assert_eq "$(md5_of "$VAULT/02-Library/sources/clips/c.md")" "$md5_clip" "nested file bytes unchanged"
if [[ -e "$VAULT/02-Sources/LIT-b.md" || -e "$VAULT/03-Concepts/idea-one.md" ]]; then
  _fail "a moved note is still in its legacy folder"
else
  _pass "moved notes are gone from the legacy folders"
fi
assert_eq "$(snapshot_dir "$VAULT/05-Tasks")" "$TASKS_BEFORE" "05-Tasks/ untouched"
assert_contains "$VAULT/01-Projects/acme/acme.md" "[[02-Sources/LIT-b|the old way]]" "notes are never rewritten"

BACKUP="$(find "$BACKUPS" -maxdepth 1 -name 'vault-backup-library-migration-*.tar.gz' 2>/dev/null | head -n 1)"
if [[ -n "$BACKUP" && -s "$BACKUP" ]]; then _pass "backup written to ~/WORK/vault-BACKUPS/"; else _fail "no backup in $BACKUPS"; fi
if [[ -n "$BACKUP" ]] && tar -tzf "$BACKUP" | grep -qF "vault/02-Sources/SRC-2026-01-01-a.md"; then
  _pass "backup holds the pre-move 02-Sources/"
else
  _fail "backup is missing 02-Sources/SRC-2026-01-01-a.md"
fi
if [[ -n "$BACKUP" ]] && tar -tzf "$BACKUP" | grep -qF "vault/03-Concepts/idea-one.md"; then
  _pass "backup holds the pre-move 03-Concepts/"
else
  _fail "backup is missing 03-Concepts/idea-one.md"
fi
if [[ -e "$HOME/Desktop" ]]; then _fail "something was written under ~/Desktop"; else _pass "nothing written under ~/Desktop"; fi

# Empty legacy folders stay (removable) unless --remove-empty.
assert_dir "$VAULT/02-Sources" "empty 02-Sources/ left in place by default"
if printf '%s' "$A_OUT" | grep -qF "02-Sources/ is now empty"; then _pass "says the legacy folder is empty and how to remove it"; else _fail "no empty-folder hint: $A_OUT"; fi

# ---------------------------------------------------------------------------
# Re-runs are safe; --remove-empty clears the empty legacy folders.
# ---------------------------------------------------------------------------
R_RC=0
R_OUT="$(bash "$MIGRATE" --vault "$VAULT" --apply --remove-empty 2>&1)" || R_RC=$?
assert_eq "$R_RC" "0" "a second --apply exits 0"
if printf '%s' "$R_OUT" | grep -qF "0 to move, 0 conflicting"; then _pass "a second run has nothing to move"; else _fail "second run output: $R_OUT"; fi
if [[ -e "$VAULT/02-Sources" || -e "$VAULT/03-Concepts" ]]; then
  _fail "--remove-empty left an empty legacy folder"
else
  _pass "--remove-empty removed the empty legacy folders"
fi
N_RC=0
N_OUT="$(bash "$MIGRATE" --vault "$VAULT" 2>&1)" || N_RC=$?
assert_eq "$N_RC" "0" "a migrated vault exits 0"
if printf '%s' "$N_OUT" | grep -qF "Nothing to migrate"; then _pass "a migrated vault has nothing to migrate"; else _fail "migrated-vault output: $N_OUT"; fi
assert_eq "$(snapshot_dir "$VAULT/05-Tasks")" "$TASKS_BEFORE" "05-Tasks/ still untouched"

# ---------------------------------------------------------------------------
# --full-backup hands the backup to bin/backup-vault.sh: the whole vault.
# ---------------------------------------------------------------------------
FVAULT="$TMPROOT/fullv"
legacy_vault "$FVAULT"
bash "$MIGRATE" --vault "$FVAULT" --apply --full-backup >/dev/null 2>&1
assert_eq "$?" "0" "--apply --full-backup exits 0"
FULL="$(find "$HOME/WORK/fullv-BACKUPS" -maxdepth 1 -name 'fullv-backup-*.tar.gz' 2>/dev/null | head -n 1)"
if [[ -n "$FULL" ]] && tar -tzf "$FULL" | grep -qF "fullv/05-Tasks/TASKS-SAMPLE.md"; then
  _pass "--full-backup tarballs the whole vault"
else
  _fail "--full-backup wrote no whole-vault tarball"
fi
assert_file "$FVAULT/02-Library/ideas/idea-one.md" "--full-backup still moves the notes"

assert_report
