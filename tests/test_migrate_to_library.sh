#!/usr/bin/env bash
# tests/test_migrate_to_library.sh
# scripts/migrate-to-library.sh moves a pre-2026-11-05 vault onto Library v2:
# 02-Sources/* -> 02-Library/sources/, 03-Concepts/* -> 02-Library/ideas/,
# 04-Index/ -> 03-Index/, 05-Tasks/ -> 04-Tasks/.
# - dry run by default: the vault stays byte-identical and no backup is written
# - --apply backs up first (~/WORK/<vault>-BACKUPS/), then moves, byte for byte
# - any name conflict refuses the whole run and changes nothing
# - task queries are rewritten only inside ```tasks blocks; task lines and 🆔 never
# - in a git repo, tracked paths move with git mv, so a 05-Tasks submodule follows
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
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com
MIGRATE="$REPO_ROOT/scripts/migrate-to-library.sh"
assert_file "$MIGRATE" "scripts/migrate-to-library.sh exists"

TASK_LINE='- [ ] tidy 05-Tasks notes 📅 2026-11-10 🆔 m-0a1b2c3d'
tasks_hub() { # the hub note: two queries, a task line and a non-tasks code block
  printf -- '---\ntitle: "TASKS"\n---\n\n```tasks\nnot done\npath includes 05-Tasks\npath does not include 04-Index\n```\n\n%s\n\n```bash\nls 05-Tasks\n```\n' "$TASK_LINE"
}

# A vault on the old layout, seeded the way install.sh used to seed it.
legacy_vault() {
  local v="$1"
  mkdir -p "$v/01-Projects/acme" "$v/02-Sources/clips" "$v/03-Concepts" "$v/04-Index" "$v/05-Tasks"
  touch "$v/02-Sources/.gitkeep" "$v/03-Concepts/.gitkeep" "$v/05-Tasks/.gitkeep"
  printf -- '---\ntitle: "acme"\ntype: project\n---\nSee [[idea-one]] and [[02-Sources/LIT-b|the old way]].\n\n```tasks\npath includes 05-Tasks/TASKS-ACME\n```\n' > "$v/01-Projects/acme/acme.md"
  printf -- '---\ntitle: "a"\ntype: source\n---\nsource a\n' > "$v/02-Sources/SRC-2026-01-01-a.md"
  printf -- '---\ntitle: "b"\ntype: source\n---\nsource b\n' > "$v/02-Sources/LIT-b.md"
  printf 'nested clip\n' > "$v/02-Sources/clips/c.md"
  printf -- '---\ntitle: "idea-one"\ntype: concept\nowner: human\n---\nFrom [[SRC-2026-01-01-a]].\n' > "$v/03-Concepts/idea-one.md"
  printf -- '---\ntitle: "Index"\ntype: index\n---\n- [[idea-one]]\n' > "$v/04-Index/Index.md"
  printf -- '%s\n' "$TASK_LINE" > "$v/05-Tasks/TASKS-SAMPLE.md"
  tasks_hub > "$v/05-Tasks/TASKS.md"
}

VAULT="$TMPROOT/vault"
legacy_vault "$VAULT"
BACKUPS="$HOME/WORK/vault-BACKUPS"
md5_a="$(md5_of "$VAULT/02-Sources/SRC-2026-01-01-a.md")"
md5_idea="$(md5_of "$VAULT/03-Concepts/idea-one.md")"
md5_clip="$(md5_of "$VAULT/02-Sources/clips/c.md")"
md5_index="$(md5_of "$VAULT/04-Index/Index.md")"
md5_sample="$(md5_of "$VAULT/05-Tasks/TASKS-SAMPLE.md")"

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
if [[ -d "$VAULT/02-Library" || -d "$VAULT/03-Index" || -d "$VAULT/04-Tasks" ]]; then
  _fail "dry run created a folder"
else
  _pass "dry run creates no folders"
fi
if [[ -e "$BACKUPS" ]]; then _fail "dry run wrote a backup"; else _pass "dry run writes no backup"; fi
for want in "02-Sources/SRC-2026-01-01-a.md  ->  02-Library/sources/SRC-2026-01-01-a.md" \
            "02-Sources/clips  ->  02-Library/sources/clips" \
            "03-Concepts/idea-one.md  ->  02-Library/ideas/idea-one.md" \
            "rename    04-Index/  ->  03-Index/" \
            "rename    05-Tasks/  ->  04-Tasks/" \
            "    05-Tasks/TASKS.md" \
            "    01-Projects/acme/acme.md" \
            "4 to move, 2 to rename, 2 with task queries to rewrite, 0 conflicting" \
            "05-Tasks/ becomes 04-Tasks/" \
            "old: $(cd -P "$VAULT" && pwd -P)/05-Tasks"; do
  if printf '%s' "$DRY_OUT" | grep -qF -- "$want"; then _pass "dry run says: $want"; else _fail "dry run is missing: $want"; fi
done
if printf '%s' "$DRY_OUT" | grep -q '\.gitkeep'; then _fail "dry run plans to move .gitkeep"; else _pass "placeholders are not moved"; fi
if printf '%s' "$DRY_OUT" | grep -qF "link into a renamed folder by path"; then
  _pass "dry run flags the path-style link"
else
  _fail "dry run missed the path-style link in acme.md"
fi

# ---------------------------------------------------------------------------
# Conflicts refuse everything: nothing changes, no backup.
# ---------------------------------------------------------------------------
CVAULT="$TMPROOT/conflict"
legacy_vault "$CVAULT"
mkdir -p "$CVAULT/02-Library/sources"
printf 'already here\n' > "$CVAULT/02-Library/sources/LIT-b.md"
C_SNAP="$(snapshot_dir "$CVAULT")"
C_RC=0
C_OUT="$(bash "$MIGRATE" --vault "$CVAULT" --apply 2>&1)" || C_RC=$?
assert_eq "$C_RC" "3" "a name conflict exits 3"
assert_eq "$(snapshot_dir "$CVAULT")" "$C_SNAP" "a conflict changes nothing"
if printf '%s' "$C_OUT" | grep -qF "02-Library/sources/LIT-b.md already exists"; then _pass "the conflict is named"; else _fail "conflict output: $C_OUT"; fi
if [[ -e "$HOME/WORK/conflict-BACKUPS" ]]; then _fail "a refused run wrote a backup"; else _pass "a refused run writes no backup"; fi

IVAULT="$TMPROOT/indexclash"
legacy_vault "$IVAULT"
mkdir -p "$IVAULT/03-Index"
printf 'a real map\n' > "$IVAULT/03-Index/Tech-Index.md"
I_SNAP="$(snapshot_dir "$IVAULT")"
bash "$MIGRATE" --vault "$IVAULT" --apply >/dev/null 2>&1
assert_eq "$?" "3" "an existing 03-Index/ with notes in it exits 3"
assert_eq "$(snapshot_dir "$IVAULT")" "$I_SNAP" "the index clash changes nothing"

SVAULT="$TMPROOT/symlinked"
mkdir -p "$SVAULT/elsewhere"
ln -s "$SVAULT/elsewhere" "$SVAULT/05-Tasks"
bash "$MIGRATE" --vault "$SVAULT" --apply >/dev/null 2>&1
assert_eq "$?" "3" "a symlinked 05-Tasks/ exits 3"

# ---------------------------------------------------------------------------
# --apply: backup first, then the moves and renames, byte for byte.
# ---------------------------------------------------------------------------
mkdir -p "$VAULT/04-Tasks" && touch "$VAULT/04-Tasks/.gitkeep"   # an empty seed counts as empty
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
assert_eq "$(md5_of "$VAULT/03-Index/Index.md")" "$md5_index" "04-Index/ renamed to 03-Index/, bytes unchanged"
assert_eq "$(md5_of "$VAULT/04-Tasks/TASKS-SAMPLE.md")" "$md5_sample" "05-Tasks/ renamed to 04-Tasks/, task file bytes unchanged"
for gone in 04-Index 05-Tasks 02-Sources/LIT-b.md 03-Concepts/idea-one.md; do
  if [[ -e "$VAULT/$gone" ]]; then _fail "$gone is still there"; else _pass "$gone is gone"; fi
done

HUB="$VAULT/04-Tasks/TASKS.md"
assert_contains "$HUB" "path includes 04-Tasks" "task query rewritten to 04-Tasks"
assert_contains "$HUB" "path does not include 03-Index" "task query rewritten to 03-Index"
assert_not_contains "$HUB" "path includes 05-Tasks" "no stale 05-Tasks query left"
if grep -qxF -- "$TASK_LINE" "$HUB"; then _pass "the task line and its 🆔 are byte-identical"; else _fail "the task line changed"; fi
assert_contains "$HUB" "ls 05-Tasks" "a non-tasks code block is left alone"
assert_contains "$VAULT/01-Projects/acme/acme.md" "path includes 04-Tasks/TASKS-ACME" "queries in other notes are rewritten too"
assert_contains "$VAULT/01-Projects/acme/acme.md" "[[02-Sources/LIT-b|the old way]]" "links in notes are never rewritten"
if printf '%s' "$A_OUT" | grep -qF "05-Tasks/ becomes 04-Tasks/"; then _pass "--apply repeats the external-path warning"; else _fail "no external-path warning on --apply"; fi

BACKUP="$(find "$BACKUPS" -maxdepth 1 -name 'vault-backup-library-migration-*.tar.gz' 2>/dev/null | head -n 1)"
if [[ -n "$BACKUP" && -s "$BACKUP" ]]; then _pass "backup written to ~/WORK/vault-BACKUPS/"; else _fail "no backup in $BACKUPS"; fi
for member in vault/02-Sources/SRC-2026-01-01-a.md vault/03-Concepts/idea-one.md vault/04-Index/Index.md vault/05-Tasks/TASKS.md vault/01-Projects/acme/acme.md; do
  if [[ -n "$BACKUP" ]] && tar -tzf "$BACKUP" | grep -qxF "$member"; then
    _pass "backup holds the pre-move $member"
  else
    _fail "backup is missing $member"
  fi
done
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
if printf '%s' "$R_OUT" | grep -qF "0 to move, 0 to rename, 0 with task queries to rewrite"; then _pass "a second run has nothing to do"; else _fail "second run output: $R_OUT"; fi
if [[ -e "$VAULT/02-Sources" || -e "$VAULT/03-Concepts" ]]; then
  _fail "--remove-empty left an empty legacy folder"
else
  _pass "--remove-empty removed the empty legacy folders"
fi
N_RC=0
N_OUT="$(bash "$MIGRATE" --vault "$VAULT" 2>&1)" || N_RC=$?
assert_eq "$N_RC" "0" "a migrated vault exits 0"
if printf '%s' "$N_OUT" | grep -qF "Nothing to migrate"; then _pass "a migrated vault has nothing to migrate"; else _fail "migrated-vault output: $N_OUT"; fi

# ---------------------------------------------------------------------------
# A git vault whose 05-Tasks/ is a submodule: git mv carries .gitmodules along.
# ---------------------------------------------------------------------------
TREPO="$TMPROOT/tasks-src"
mkdir -p "$TREPO"
git -C "$TREPO" init -q
tasks_hub > "$TREPO/TASKS.md"
git -C "$TREPO" add TASKS.md && git -C "$TREPO" commit -q -m "tasks"
GVAULT="$TMPROOT/gitvault"
mkdir -p "$GVAULT/04-Index" "$GVAULT/03-Concepts"
printf -- '- [[x]]\n' > "$GVAULT/04-Index/Index.md"
printf -- 'idea\n' > "$GVAULT/03-Concepts/x.md"
git -C "$GVAULT" init -q
git -C "$GVAULT" add -A && git -C "$GVAULT" commit -q -m "vault"
git -C "$GVAULT" -c protocol.file.allow=always submodule --quiet add "$TREPO" 05-Tasks >/dev/null 2>&1
git -C "$GVAULT" commit -q -m "tasks submodule"
assert_file "$GVAULT/05-Tasks/TASKS.md" "fixture: 05-Tasks is a submodule"
G_RC=0
G_OUT="$(bash "$MIGRATE" --vault "$GVAULT" --apply 2>&1)" || G_RC=$?
assert_eq "$G_RC" "0" "--apply on a git vault exits 0"
if printf '%s' "$G_OUT" | grep -qF "tracked paths move with git mv"; then _pass "it says it is using git mv"; else _fail "git output: $G_OUT"; fi
assert_contains "$GVAULT/.gitmodules" "path = 04-Tasks" ".gitmodules follows the rename"
assert_not_contains "$GVAULT/.gitmodules" "path = 05-Tasks" ".gitmodules no longer names 05-Tasks"
if git -C "$GVAULT/04-Tasks" rev-parse HEAD >/dev/null 2>&1; then _pass "the submodule still works at 04-Tasks/"; else _fail "the submodule is broken after the rename"; fi
if git -C "$GVAULT" diff --cached --name-status | grep -qE '^R[0-9]*[[:space:]]+04-Index/Index.md[[:space:]]+03-Index/Index.md'; then
  _pass "04-Index -> 03-Index is staged as a rename"
else
  _fail "no staged rename for 04-Index: $(git -C "$GVAULT" diff --cached --name-status)"
fi
assert_contains "$GVAULT/04-Tasks/TASKS.md" "path includes 04-Tasks" "queries inside the submodule are rewritten"
if grep -qxF -- "$TASK_LINE" "$GVAULT/04-Tasks/TASKS.md"; then _pass "submodule task line untouched"; else _fail "submodule task line changed"; fi
if printf '%s' "$G_OUT" | grep -qF "commit any query edits inside it"; then _pass "it reminds you to commit inside the submodule"; else _fail "no submodule commit reminder"; fi

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
