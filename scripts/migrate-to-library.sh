#!/usr/bin/env bash
#
# 2ndBrain-mogging — migrate-to-library.sh
#
# Moves a vault from the pre-2026-11-05 layout to Library v2:
#
#   02-Sources/*   ->  02-Library/sources/
#   03-Concepts/*  ->  02-Library/ideas/
#
# People and tools stay in ideas/ for now; sort them into 02-Library/people/
# and 02-Library/tools/ yourself, or let /wiki heal propose it.
#
# Usage:
#   migrate-to-library.sh [--vault PATH] [--apply] [--full-backup] [--remove-empty]
#
#   --vault PATH     The vault. Defaults to $VAULT_DIR, then the
#                    ~/.claude/.mogging-vault marker install.sh writes.
#   --apply          Do it. Without this flag the script is a dry run and
#                    changes nothing.
#   --full-backup    Tarball the whole vault with bin/backup-vault.sh instead of
#                    just the folders this script moves.
#   --remove-empty   After the move, remove 02-Sources/ and 03-Concepts/ if
#                    nothing but .gitkeep / .DS_Store is left in them.
#                    Without it they stay, empty, for you to remove.
#
# Safety:
#   - Backs up before moving: ~/WORK/<vault>-BACKUPS/<vault>-backup-library-migration-<ts>.tar.gz.
#     Never ~/Desktop, never inside the vault. A failed backup moves nothing.
#   - Refuses, and moves nothing, if any destination name already exists.
#   - Refuses symlinked legacy or Library folders, and never touches 05-Tasks/.
#   - Wikilinks resolve by note name, so moving notes breaks no [[links]].
#     Path-style links into the old folders do break; the dry run lists them.
#
# Exit codes: 0 ok (dry run, applied, or nothing to do), 1 failure,
#             2 bad usage, 3 refused (conflict or unsafe layout).

set -euo pipefail

SELF="$0"
while [ -L "$SELF" ]; do
  link="$(readlink "$SELF")"
  case "$link" in /*) SELF="$link" ;; *) SELF="$(dirname "$SELF")/$link" ;; esac
done
REPO_ROOT="$(cd -P "$(dirname "$SELF")/.." && pwd)"

usage() { sed -n '2,36p' "$SELF" | sed 's/^# \{0,1\}//'; }
die() { echo "migrate-to-library: $1" >&2; exit "${2:-1}"; }

VAULT="" APPLY=0 FULL_BACKUP=0 REMOVE_EMPTY=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --vault)
      [ "$#" -ge 2 ] && [ -n "$2" ] || die "--vault requires a path" 2
      VAULT="$2"; shift 2 ;;
    --vault=*) VAULT="${1#*=}"; shift ;;
    --apply) APPLY=1; shift ;;
    --full-backup) FULL_BACKUP=1; shift ;;
    --remove-empty) REMOVE_EMPTY=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown argument: $1 (see --help)" 2 ;;
  esac
done

if [ -z "$VAULT" ]; then VAULT="${VAULT_DIR:-}"; fi
if [ -z "$VAULT" ] && [ -f "$HOME/.claude/.mogging-vault" ]; then
  VAULT="$(head -n 1 "$HOME/.claude/.mogging-vault" | tr -d '\r\n')"
fi
[ -n "$VAULT" ] || die "no vault given. Pass --vault PATH." 2
case "/$VAULT/" in */../*) die "vault path must not contain .." 2 ;; esac
[ -d "$VAULT" ] || die "not a directory: $VAULT" 2
VAULT="$(cd -P "$VAULT" && pwd -P)"

LIB="02-Library"
# legacy folder -> Library subfolder
PAIRS="02-Sources:sources 03-Concepts:ideas"

# ---- safety checks -----------------------------------------------------------
for p in "$LIB" "$LIB/people" "$LIB/tools" "$LIB/ideas" "$LIB/sources" 02-Sources 03-Concepts; do
  if [ -L "$VAULT/$p" ]; then
    die "refused: $p is a symlink. Move it by hand, or replace it with a real folder first." 3
  fi
  if [ -e "$VAULT/$p" ] && [ ! -d "$VAULT/$p" ]; then
    die "refused: $p exists and is not a folder." 3
  fi
done

# Placeholders a legacy folder may hold that are not notes. They are never moved,
# so a seeded vault's .gitkeep can't collide with the Library's own.
is_placeholder() { case "$1" in .gitkeep|.DS_Store) return 0 ;; esac; return 1; }

# ---- plan --------------------------------------------------------------------
PLAN="$(mktemp -t mogging-migrate-plan.XXXXXX)"
trap 'rm -f "$PLAN"' EXIT
moves=0 conflicts=0
for pair in $PAIRS; do
  legacy="${pair%%:*}"
  sub="${pair#*:}"
  [ -d "$VAULT/$legacy" ] || continue
  while IFS= read -r -d '' entry; do
    name="$(basename "$entry")"
    is_placeholder "$name" && continue
    case "$name" in
      *$'\t'*|*$'\n'*) die "refused: $legacy/ holds a name with a tab or newline in it. Rename it first." 3 ;;
    esac
    src="$legacy/$name"
    dest="$LIB/$sub/$name"
    if [ -e "$VAULT/$dest" ] || [ -L "$VAULT/$dest" ]; then
      printf 'conflict\t%s\t%s\n' "$src" "$dest" >> "$PLAN"
      conflicts=$((conflicts + 1))
    else
      printf 'move\t%s\t%s\n' "$src" "$dest" >> "$PLAN"
      moves=$((moves + 1))
    fi
  done < <(find "$VAULT/$legacy" -mindepth 1 -maxdepth 1 -print0 | LC_ALL=C sort -z)
done

if [ ! -d "$VAULT/02-Sources" ] && [ ! -d "$VAULT/03-Concepts" ]; then
  echo "Nothing to migrate: $VAULT has no 02-Sources/ or 03-Concepts/."
  exit 0
fi

echo "Library v2 migration for $VAULT"
[ "$APPLY" -eq 1 ] || echo "Dry run. Nothing will change."
echo
while IFS=$'\t' read -r kind src dest; do
  case "$kind" in
    move) printf '  move      %s  ->  %s\n' "$src" "$dest" ;;
    conflict) printf '  CONFLICT  %s  ->  %s already exists\n' "$src" "$dest" ;;
  esac
done < "$PLAN"
echo
echo "$moves to move, $conflicts conflicting."

# Path-style links into the old folders break on the move. Name-style [[links]]
# don't. Report them; never rewrite a note.
pathlinks="$(cd "$VAULT" && grep -rlE --include='*.md' \
  --exclude-dir=.git --exclude-dir=node_modules --exclude-dir=.obsidian \
  --exclude-dir=02-Sources --exclude-dir=03-Concepts \
  '\[\[(02-Sources|03-Concepts)/|\]\((\.\./)*(02-Sources|03-Concepts)/' . 2>/dev/null || true)"
for legacy in 02-Sources 03-Concepts; do
  [ -d "$VAULT/$legacy" ] || continue
  more="$(cd "$VAULT" && grep -rlE --include='*.md' \
    '\[\[(02-Sources|03-Concepts)/|\]\((\.\./)*(02-Sources|03-Concepts)/' "$legacy" 2>/dev/null || true)"
  if [ -n "$more" ]; then pathlinks="$(printf '%s\n%s' "$pathlinks" "$more")"; fi
done
pathlinks="$(printf '%s\n' "$pathlinks" | sed '/^$/d; s#^\./##')"
if [ -n "$pathlinks" ]; then
  n="$(printf '%s\n' "$pathlinks" | wc -l | tr -d ' ')"
  echo
  echo "Heads up: $n note(s) link to 02-Sources/ or 03-Concepts/ by path. Those links break after the move."
  echo "Switch them to [[note-name]] links (by hand or /wiki heal):"
  printf '%s\n' "$pathlinks" | sed -n '1,20s/^/  /p'
  if [ "$n" -gt 20 ]; then echo "  ...and $((n - 20)) more"; fi
fi

if [ "$conflicts" -gt 0 ]; then
  echo
  echo "Refused: $conflicts name(s) already exist in $LIB/. Nothing was moved."
  echo "Rename or merge those notes, then run this again."
  exit 3
fi

if [ "$APPLY" -ne 1 ]; then
  echo
  if [ "$moves" -gt 0 ]; then
    echo "Run again with --apply to move them. A backup is written first."
  else
    echo "Nothing to move. --apply --remove-empty clears the empty legacy folders."
  fi
  exit 0
fi

# ---- backup ------------------------------------------------------------------
backup() {
  local name backup_dir d
  name="$(basename "$VAULT")"
  case "$name" in ""|/|.|..) die "can't name a backup for vault path $VAULT" 1 ;; esac
  if [ "$FULL_BACKUP" -eq 1 ]; then
    OUT="$(bash "$REPO_ROOT/bin/backup-vault.sh" "$VAULT")" || die "backup failed. Nothing was moved." 1
  else
    # Only the folders this script touches. A mature vault carries embedded clones
    # and node_modules, and a whole-vault tarball of it can run to tens of GB.
    backup_dir="$HOME/WORK/${name}-BACKUPS"
    case "$backup_dir/" in "$VAULT/"*) die "backup destination is inside the vault. Nothing was moved." 1 ;; esac
    mkdir -p "$backup_dir" || die "can't create $backup_dir. Nothing was moved." 1
    backup_dir="$(cd -P "$backup_dir" && pwd -P)"
    case "$backup_dir/" in
      "$VAULT/"*) die "backup destination resolves inside the vault. Nothing was moved." 1 ;;
      */Desktop/*) die "backup destination resolves under Desktop, which is never used for backups. Nothing was moved." 1 ;;
    esac
    set --
    for d in 02-Sources 03-Concepts "$LIB"; do
      if [ -d "$VAULT/$d" ]; then set -- "$@" "$name/$d"; fi
    done
    OUT="$backup_dir/${name}-backup-library-migration-$(date +%Y%m%d-%H%M%S)-$$.tar.gz"
    [ ! -e "$OUT" ] || die "backup file already exists: $OUT. Nothing was moved." 1
    tar --exclude='.DS_Store' -czf "$OUT" -C "$(dirname "$VAULT")" -- "$@" \
      || { rm -f "$OUT"; die "backup failed. Nothing was moved." 1; }
  fi
  [ -s "$OUT" ] || die "backup is empty or missing: $OUT. Nothing was moved." 1
  echo
  echo "Backup: $OUT"
}

# ---- move --------------------------------------------------------------------
move_all() {
  local sub kind src dest done_moves=0
  for sub in people tools ideas sources; do
    mkdir -p "$VAULT/$LIB/$sub"
  done
  while IFS=$'\t' read -r kind src dest; do
    [ "$kind" = move ] || continue
    # -n never overwrites, as a second guard behind the conflict check above.
    mv -n "$VAULT/$src" "$VAULT/$dest"
    if [ -e "$VAULT/$src" ] || [ -L "$VAULT/$src" ]; then
      die "stopped: $src could not be moved (did something create $dest meanwhile?). $done_moves moved so far; the backup above has the rest." 1
    fi
    done_moves=$((done_moves + 1))
  done < "$PLAN"
  echo "Moved $done_moves item(s) into $LIB/."
}

# Nothing to move means nothing to back up; go straight to the leftovers.
if [ "$moves" -gt 0 ]; then
  backup
  move_all
fi

# ---- what's left -------------------------------------------------------------
for legacy in 02-Sources 03-Concepts; do
  [ -d "$VAULT/$legacy" ] || continue
  leftover=0
  while IFS= read -r -d '' entry; do
    is_placeholder "$(basename "$entry")" || leftover=1
  done < <(find "$VAULT/$legacy" -mindepth 1 -maxdepth 1 -print0)
  if [ "$leftover" -eq 1 ]; then
    echo "$legacy/ still has entries; nothing more was done with it."
  elif [ "$REMOVE_EMPTY" -eq 1 ]; then
    rm -f "$VAULT/$legacy/.gitkeep" "$VAULT/$legacy/.DS_Store"
    rmdir "$VAULT/$legacy" && echo "Removed the empty $legacy/."
  else
    echo "$legacy/ is now empty. Remove it with: rm -f \"$VAULT/$legacy/.gitkeep\" \"$VAULT/$legacy/.DS_Store\" && rmdir \"$VAULT/$legacy\""
  fi
done

echo
echo "Done. If the vault is a git repo, commit the move with a bot prefix, e.g.:"
echo "  git -C \"$VAULT\" add -A -- 02-Sources 03-Concepts $LIB && git -C \"$VAULT\" commit -m \"[bot:mogging-migrate] move 02-Sources and 03-Concepts into 02-Library\""
