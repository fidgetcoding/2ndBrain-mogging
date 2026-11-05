#!/usr/bin/env bash
#
# 2ndBrain-mogging — migrate-to-library.sh
#
# Moves a vault from the pre-2026-11-05 layout to Library v2:
#
#   02-Sources/*   ->  02-Library/sources/
#   03-Concepts/*  ->  02-Library/ideas/
#   04-Index/      ->  03-Index/
#   05-Tasks/      ->  04-Tasks/
#
# and rewrites Obsidian Tasks queries that name the old folders
# (`path includes 05-Tasks` -> `path includes 04-Tasks`, and 04-Index the same
# way). Only lines inside ```tasks query blocks change; task lines and their 🆔
# tokens are never touched.
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
#                    just the folders this script touches.
#   --remove-empty   After the move, remove 02-Sources/ and 03-Concepts/ if
#                    nothing but .gitkeep / .DS_Store is left in them.
#                    Without it they stay, empty, for you to remove.
#
# Safety:
#   - Backs up before changing anything:
#     ~/WORK/<vault>-BACKUPS/<vault>-backup-library-migration-<ts>.tar.gz.
#     Never ~/Desktop, never inside the vault. A failed backup changes nothing.
#   - Refuses, and changes nothing, if any destination name already exists.
#     A destination folder holding only .gitkeep / .DS_Store counts as empty.
#   - Refuses symlinked legacy, Library, index or task folders.
#   - In a git repo, tracked paths move with `git mv`, so a 05-Tasks/ submodule
#     keeps working and .gitmodules follows it.
#   - Wikilinks resolve by note name, so moving notes breaks no [[links]].
#     Path-style links into the old folders do break; the dry run lists them.
#   - Anything outside the vault that names the old 05-Tasks/ path (a sync
#     daemon, a launchd plist, a path filter) has to be updated by hand. The
#     script says so loudly and lists the LaunchAgents it can see.
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

usage() { sed -n '2,50p' "$SELF" | sed 's/^# \{0,1\}//'; }
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
MOVES="02-Sources:sources 03-Concepts:ideas"   # legacy folder : Library subfolder
RENAMES="04-Index:03-Index 05-Tasks:04-Tasks"  # legacy folder : new folder
STALE_RE='05-Tasks|04-Index'

IN_GIT=0
if command -v git >/dev/null 2>&1 && git -C "$VAULT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  IN_GIT=1
fi
tracked() { [ "$IN_GIT" -eq 1 ] && git -C "$VAULT" ls-files --error-unmatch -- "$1" >/dev/null 2>&1; }

# Move one vault-relative path. Tracked paths go through git so history and
# submodules follow; everything else is a plain move that never overwrites.
vault_mv() {
  local src="$1" dest="$2"
  if tracked "$src"; then
    git -C "$VAULT" mv -- "$src" "$dest" || die "git mv $src $dest failed. The backup has the pre-move state." 1
  else
    mv -n "$VAULT/$src" "$VAULT/$dest"
  fi
  if [ -e "$VAULT/$src" ] || [ -L "$VAULT/$src" ]; then
    die "stopped: $src could not be moved to $dest. The backup has the pre-move state." 1
  fi
}

# Placeholders a folder may hold that are not notes. They are never moved, so a
# seeded vault's .gitkeep can't collide with the Library's own.
is_placeholder() { case "$1" in .gitkeep|.DS_Store) return 0 ;; esac; return 1; }
only_placeholders() {
  local entry
  while IFS= read -r -d '' entry; do
    is_placeholder "$(basename "$entry")" || return 1
  done < <(find "$1" -mindepth 1 -maxdepth 1 -print0)
  return 0
}

# Rewrite stale folder names inside ```tasks / ~~~tasks query blocks only. Task
# lines and any line holding a 🆔 pass through byte for byte. stdin -> stdout.
# shellcheck disable=SC2016  # perl code, not shell: nothing should expand
QUERY_FIX='
  if (!$in && /^\s*(`{3,}|~{3,})\s*tasks\s*$/) { $fence = $1; $in = 1; print; next; }
  if ($in && /^\s*\Q$fence\E[`~]*\s*$/) { $in = 0; print; next; }
  if ($in && !/^\s*[-*+] \[.\]/ && index($_, "\xF0\x9F\x86\x94") < 0) {
    s/05-Tasks/04-Tasks/g; s/04-Index/03-Index/g;
  }
  print;
'
# Vault-relative .md files whose task queries would change.
stale_query_files() {
  local f tmp
  tmp="$(mktemp -t mogging-migrate-q.XXXXXX)"
  ( cd "$VAULT" && grep -rlE --include='*.md' --exclude-dir=.git --exclude-dir=node_modules \
      --exclude-dir=.obsidian --exclude-dir=.trash "$STALE_RE" . 2>/dev/null || true ) |
  sed 's#^\./##' | while IFS= read -r f; do
    [ -f "$VAULT/$f" ] && [ ! -L "$VAULT/$f" ] || continue
    perl -ne "$QUERY_FIX" "$VAULT/$f" > "$tmp"
    cmp -s "$VAULT/$f" "$tmp" || printf '%s\n' "$f"
  done
  rm -f "$tmp"
}

# ---- safety checks -----------------------------------------------------------
for p in "$LIB" "$LIB/people" "$LIB/tools" "$LIB/ideas" "$LIB/sources" \
         02-Sources 03-Concepts 04-Index 03-Index 05-Tasks 04-Tasks; do
  if [ -L "$VAULT/$p" ]; then
    die "refused: $p is a symlink. Move it by hand, or replace it with a real folder first." 3
  fi
  if [ -e "$VAULT/$p" ] && [ ! -d "$VAULT/$p" ]; then
    die "refused: $p exists and is not a folder." 3
  fi
done

# ---- plan --------------------------------------------------------------------
PLAN="$(mktemp -t mogging-migrate-plan.XXXXXX)"
trap 'rm -f "$PLAN"' EXIT
moves=0 renames=0 conflicts=0 tasks_rename=0
for pair in $MOVES; do
  legacy="${pair%%:*}" sub="${pair#*:}"
  [ -d "$VAULT/$legacy" ] || continue
  while IFS= read -r -d '' entry; do
    name="$(basename "$entry")"
    is_placeholder "$name" && continue
    case "$name" in
      *$'\t'*|*$'\n'*) die "refused: $legacy/ holds a name with a tab or newline in it. Rename it first." 3 ;;
    esac
    if [ -e "$VAULT/$LIB/$sub/$name" ] || [ -L "$VAULT/$LIB/$sub/$name" ]; then
      printf 'conflict\t%s\t%s\n' "$legacy/$name" "$LIB/$sub/$name" >> "$PLAN"; conflicts=$((conflicts + 1))
    else
      printf 'move\t%s\t%s\n' "$legacy/$name" "$LIB/$sub/$name" >> "$PLAN"; moves=$((moves + 1))
    fi
  done < <(find "$VAULT/$legacy" -mindepth 1 -maxdepth 1 -print0 | LC_ALL=C sort -z)
done
for pair in $RENAMES; do
  legacy="${pair%%:*}" new="${pair#*:}"
  [ -d "$VAULT/$legacy" ] || continue
  if [ -d "$VAULT/$new" ] && ! only_placeholders "$VAULT/$new"; then
    printf 'conflict\t%s\t%s\n' "$legacy" "$new" >> "$PLAN"; conflicts=$((conflicts + 1))
    continue
  fi
  if tracked "$legacy" && ! err="$(git -C "$VAULT" mv -n -- "$legacy" "$new" 2>&1)"; then
    die "refused: git mv $legacy $new would fail: $err" 3
  fi
  printf 'rename\t%s\t%s\n' "$legacy" "$new" >> "$PLAN"; renames=$((renames + 1))
  [ "$legacy" = 05-Tasks ] && tasks_rename=1
done
QFILES="$(stale_query_files)"
qcount=0
[ -z "$QFILES" ] || qcount="$(printf '%s\n' "$QFILES" | wc -l | tr -d ' ')"

legacy_left=0
for d in 02-Sources 03-Concepts 04-Index 05-Tasks; do
  if [ -d "$VAULT/$d" ]; then legacy_left=1; fi
done
if [ "$legacy_left" -eq 0 ] && [ "$qcount" -eq 0 ]; then
  echo "Nothing to migrate: $VAULT is already on the Library v2 layout."
  exit 0
fi

warn_external_paths() {
  local plist hits=""
  echo
  echo "!!! ============================================================== !!!"
  echo "!!!  05-Tasks/ becomes 04-Tasks/. Anything OUTSIDE this vault that   !!!"
  echo "!!!  names the old path must be updated by hand, or it stops syncing:!!!"
  echo "!!!    - task sync daemons (e.g. obsidian-tasks-sync's local daemon) !!!"
  echo "!!!    - launchd plists, cron jobs, shell aliases and scripts        !!!"
  echo "!!!    - n8n or other sync path filters that use the vault path      !!!"
  echo "!!! ============================================================== !!!"
  echo "    old: $VAULT/05-Tasks"
  echo "    new: $VAULT/04-Tasks"
  for plist in "$HOME"/Library/LaunchAgents/*.plist; do
    [ -f "$plist" ] || continue
    if grep -qF "$VAULT/05-Tasks" "$plist" 2>/dev/null; then hits="$hits    $plist"$'\n'; fi
  done
  if [ -n "$hits" ]; then
    echo "    LaunchAgents that name the old path:"
    printf '%s' "$hits"
  fi
}

echo "Library v2 migration for $VAULT"
[ "$APPLY" -eq 1 ] || echo "Dry run. Nothing will change."
[ "$IN_GIT" -eq 0 ] || echo "Git repo: tracked paths move with git mv."
echo
while IFS=$'\t' read -r kind src dest; do
  case "$kind" in
    move) printf '  move      %s  ->  %s\n' "$src" "$dest" ;;
    rename) printf '  rename    %s/  ->  %s/\n' "$src" "$dest" ;;
    conflict) printf '  CONFLICT  %s  ->  %s already exists\n' "$src" "$dest" ;;
  esac
done < "$PLAN"
if [ "$qcount" -gt 0 ]; then
  echo "  Tasks queries naming 05-Tasks or 04-Index, to rewrite inside \`\`\`tasks blocks only:"
  printf '%s\n' "$QFILES" | sed -n '1,20s/^/    /p'
  if [ "$qcount" -gt 20 ]; then echo "    ...and $((qcount - 20)) more"; fi
fi
echo
echo "$moves to move, $renames to rename, $qcount with task queries to rewrite, $conflicts conflicting."

# Path-style links into the old folders break on the move. Name-style [[links]]
# don't. Report them; never rewrite a note.
pathlinks="$(cd "$VAULT" && grep -rlE --include='*.md' \
  --exclude-dir=.git --exclude-dir=node_modules --exclude-dir=.obsidian \
  '\[\[(02-Sources|03-Concepts|04-Index|05-Tasks)/|\]\((\.\./)*(02-Sources|03-Concepts|04-Index|05-Tasks)/' . 2>/dev/null || true)"
pathlinks="$(printf '%s\n' "$pathlinks" | sed '/^$/d; s#^\./##')"
if [ -n "$pathlinks" ]; then
  n="$(printf '%s\n' "$pathlinks" | wc -l | tr -d ' ')"
  echo
  echo "Heads up: $n note(s) link into a renamed folder by path. Those links break after the move."
  echo "Switch them to [[note-name]] links (by hand or /wiki heal):"
  printf '%s\n' "$pathlinks" | sed -n '1,20s/^/  /p'
  if [ "$n" -gt 20 ]; then echo "  ...and $((n - 20)) more"; fi
fi

if [ "$conflicts" -gt 0 ]; then
  echo
  echo "Refused: $conflicts destination name(s) already exist. Nothing was changed."
  echo "Rename or merge those notes (or empty the folder), then run this again."
  exit 3
fi

if [ "$tasks_rename" -eq 1 ]; then warn_external_paths; fi

if [ "$APPLY" -ne 1 ]; then
  echo
  if [ $((moves + renames + qcount)) -gt 0 ]; then
    echo "Run again with --apply to do it. A backup is written first."
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
    OUT="$(bash "$REPO_ROOT/bin/backup-vault.sh" "$VAULT")" || die "backup failed. Nothing was changed." 1
  else
    # Only the folders this script touches, plus the files whose queries it
    # rewrites. A mature vault carries embedded clones and node_modules, and a
    # whole-vault tarball of it can run to tens of GB.
    backup_dir="$HOME/WORK/${name}-BACKUPS"
    case "$backup_dir/" in "$VAULT/"*) die "backup destination is inside the vault. Nothing was changed." 1 ;; esac
    mkdir -p "$backup_dir" || die "can't create $backup_dir. Nothing was changed." 1
    backup_dir="$(cd -P "$backup_dir" && pwd -P)"
    case "$backup_dir/" in
      "$VAULT/"*) die "backup destination resolves inside the vault. Nothing was changed." 1 ;;
      */Desktop/*) die "backup destination resolves under Desktop, which is never used for backups. Nothing was changed." 1 ;;
    esac
    set --
    for d in 02-Sources 03-Concepts "$LIB" 04-Index 03-Index 05-Tasks 04-Tasks .gitmodules; do
      if [ -e "$VAULT/$d" ]; then set -- "$@" "$name/$d"; fi
    done
    if [ -n "$QFILES" ]; then
      while IFS= read -r d; do set -- "$@" "$name/$d"; done <<EOF
$QFILES
EOF
    fi
    OUT="$backup_dir/${name}-backup-library-migration-$(date +%Y%m%d-%H%M%S)-$$.tar.gz"
    [ ! -e "$OUT" ] || die "backup file already exists: $OUT. Nothing was changed." 1
    tar --exclude='.DS_Store' -czf "$OUT" -C "$(dirname "$VAULT")" -- "$@" \
      || { rm -f "$OUT"; die "backup failed. Nothing was changed." 1; }
  fi
  [ -s "$OUT" ] || die "backup is empty or missing: $OUT. Nothing was changed." 1
  echo
  echo "Backup: $OUT"
}

# ---- apply -------------------------------------------------------------------
apply_plan() {
  local sub kind src dest p done_moves=0 done_renames=0
  if [ "$moves" -gt 0 ]; then
    for sub in people tools ideas sources; do mkdir -p "$VAULT/$LIB/$sub"; done
  fi
  while IFS=$'\t' read -r kind src dest; do
    case "$kind" in
      move) vault_mv "$src" "$dest"; done_moves=$((done_moves + 1)) ;;
      rename)
        if [ -d "$VAULT/$dest" ]; then
          # Empty but for placeholders (checked in the plan). Clear it so the
          # rename lands as the folder, not inside it.
          for p in .gitkeep .DS_Store; do
            if tracked "$dest/$p"; then git -C "$VAULT" rm -q --cached -- "$dest/$p" >/dev/null; fi
            rm -f "$VAULT/$dest/$p"
          done
          rmdir "$VAULT/$dest" || die "could not clear the empty $dest/. Nothing more was changed." 1
        fi
        vault_mv "$src" "$dest"; done_renames=$((done_renames + 1)) ;;
    esac
  done < "$PLAN"
  echo "Moved $done_moves item(s) into $LIB/ and renamed $done_renames folder(s)."
}

rewrite_queries() {
  local f tmp n=0
  tmp="$(mktemp -t mogging-migrate-w.XXXXXX)"
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    perl -ne "$QUERY_FIX" "$VAULT/$f" > "$tmp"
    # cat > keeps the file's inode, mode and any hard links.
    if ! cmp -s "$VAULT/$f" "$tmp"; then cat "$tmp" > "$VAULT/$f"; n=$((n + 1)); fi
  done <<EOF
$(stale_query_files)
EOF
  rm -f "$tmp"
  echo "Rewrote task queries in $n file(s)."
}

backup
apply_plan
rewrite_queries

# ---- what's left -------------------------------------------------------------
for legacy in 02-Sources 03-Concepts; do
  [ -d "$VAULT/$legacy" ] || continue
  if ! only_placeholders "$VAULT/$legacy"; then
    echo "$legacy/ still has entries; nothing more was done with it."
  elif [ "$REMOVE_EMPTY" -eq 1 ]; then
    rm -f "$VAULT/$legacy/.gitkeep" "$VAULT/$legacy/.DS_Store"
    rmdir "$VAULT/$legacy" && echo "Removed the empty $legacy/."
  else
    echo "$legacy/ is now empty. Remove it with: rm -f \"$VAULT/$legacy/.gitkeep\" \"$VAULT/$legacy/.DS_Store\" && rmdir \"$VAULT/$legacy\""
  fi
done
if [ "$tasks_rename" -eq 1 ]; then
  warn_external_paths
  if [ -f "$VAULT/04-Tasks/.git" ] || [ -d "$VAULT/04-Tasks/.git" ]; then
    echo "    04-Tasks/ is its own git repo (submodule): commit any query edits inside it too."
  fi
fi

echo
echo "Done. Review with git status if the vault is a git repo, then commit with a bot prefix,"
echo "e.g. [bot:mogging-migrate] move the vault onto the Library v2 layout"
