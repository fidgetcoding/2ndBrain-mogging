#!/usr/bin/env bash
# bin/lib/vault-gate.sh: the deterministic half of the vault's write rules.
#
# Skills are instructions to a model, so a rule that only lives in a SKILL.md can
# be forgotten. These functions are the same rules as code, shared by bin/save,
# bin/wiki and hooks/vault-guard.sh. Sourced, never run. Bash 3.2 + jq + awk only,
# because install.sh guarantees those and does not guarantee Node.
#
# Exit codes used across the gate:
#   0  allowed
#   1  a task ID rule was broken
#   2  bad usage
#   3  the path is refused for this skill

GATE_LIB_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

gate_lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

# Physical absolute path of $1 (absolute, or relative to the vault $2). The file
# and any trailing folders may not exist yet. A ".." anywhere is refused rather
# than resolved, the same call install.sh makes for --vault.
gate_resolve() {
  local p="$1" base="$2" tail="" link n=0
  case "$p" in *$'\n'*|*$'\r'*|*$'\t'*) return 1 ;; esac
  case "/$p/" in */../*) return 1 ;; esac
  case "$p" in /*) ;; *) p="$base/$p" ;; esac
  while [ -L "$p" ] && [ "$n" -lt 40 ]; do
    link="$(readlink "$p")"
    case "$link" in
      /*) p="$link" ;;
      *) p="$(dirname "$p")/$link" ;;
    esac
    n=$((n + 1))
  done
  [ "$n" -lt 40 ] || return 1
  case "/$p/" in */../*) return 1 ;; esac
  while [ ! -d "$p" ]; do
    [ ! -L "$p" ] || return 1
    if [ -n "$tail" ] && [ -e "$p" ]; then return 1; fi
    tail="/$(basename "$p")$tail"
    p="$(dirname "$p")"
  done
  printf '%s%s\n' "$(cd -P "$p" && pwd -P)" "$tail"
}

# Path of $1 relative to the vault $2. Fails when it is outside the vault.
gate_relpath() {
  local target="$1" vault="$2" abs root
  root="$(cd -P "$vault" >/dev/null 2>&1 && pwd -P)" || return 1
  abs="$(gate_resolve "$target" "$root")" || return 1
  case "$abs" in
    "$root") return 1 ;;
    "$root"/*) printf '%s\n' "${abs#"$root"/}" ;;
    *) return 1 ;;
  esac
}

# Value of a top-level frontmatter key, quotes stripped. Empty when absent.
gate_frontmatter() {
  local file="$1" key="$2"
  [ -f "$file" ] || return 0
  LC_ALL=C awk -v key="$key" '
    NR == 1 && $0 !~ /^---[ \t\r]*$/ { exit }
    NR > 1 && /^---[ \t\r]*$/ { exit }
    NR > 1 && index($0, key ":") == 1 {
      v = substr($0, length(key) + 2)
      sub(/[ \t]+#.*$/, "", v)
      gsub(/^[ \t"'"'"']+|[ \t"'"'"'\r]+$/, "", v)
      print v
      exit
    }
  ' "$file"
}

# Which of the regimes from PHILOSOPHY.md a vault-relative path falls under, plus
# FORBIDDEN for the paths no skill may write and RETIRED for the killed folders
# (02-Sources/ and 03-Concepts/ among them since Library v2). Folder names compare lowercased
# because macOS volumes are usually case-insensitive: 05-tasks/x.md IS 05-Tasks.
gate_regime() {
  local vault="$1" rel="$2" lower base stem dir
  lower="$(gate_lower "$rel")"
  base="$(basename "$lower")"
  case "/$lower/" in */.git/*|*/node_modules/*) echo FORBIDDEN; return ;; esac
  case "$base" in .env|.env.*) echo FORBIDDEN; return ;; esac
  [ "$lower" = "claude.md" ] && { echo FORBIDDEN; return; }
  case "$lower" in 05-tasks|05-tasks/*) echo SYNC; return ;; esac
  # Retired folders: a legacy vault may still have them, and skills may read
  # them, but nothing new lands there. scripts/migrate-to-library.sh moves them.
  case "$lower" in
    00-inbox/*|00-captures/*|01-fleeting/*|01-conversations/*|02-literature/*|02-sources/*|03-concepts/*|03-permanent/*|04-moc/*|05-templates/*|06-assets/*|07-projects/*|08-tasks/*)
      echo RETIRED; return ;;
  esac
  if [ "$(gate_frontmatter "$vault/$rel" owner)" = "human" ]; then
    echo HUMAN
    return
  fi
  case "$lower" in
    01-projects/*/*.md)
      stem="${base%.md}"
      dir="$(basename "$(dirname "$lower")")"
      if [ "$stem" = "$dir" ]; then echo PROJECT; return; fi
      ;;
  esac
  echo LLM
}

# What a skill may do with each regime. Prints the reason when it refuses.
gate_skill_allows() {
  local skill="$1" regime="$2" rel="$3"
  case "$regime" in
    LLM) return 0 ;;
    FORBIDDEN)
      echo "refused: $rel is on the forbidden list (.env, .git, node_modules, root CLAUDE.md). No skill writes there."
      return 3
      ;;
    SYNC)
      [ "$skill" = "save" ] && return 0
      echo "refused: $rel is under 05-Tasks/, which the Obsidian Tasks plugin and the n8n sync own. /$skill may read it and never writes it."
      return 3
      ;;
    RETIRED)
      echo "refused: $rel is in a retired folder. Sources go to 02-Library/sources/ (or the project's notes/), ideas to 02-Library/ideas/. scripts/migrate-to-library.sh moves a legacy 02-Sources/ and 03-Concepts/."
      return 3
      ;;
    HUMAN)
      echo "refused: $rel has owner: human in its frontmatter. Propose a diff, or write a sibling file, and let a human apply it."
      return 3
      ;;
    PROJECT)
      echo "refused: $rel is a project index, which is human-curated. /$skill may link to it and never rewrites it."
      return 3
      ;;
  esac
  echo "refused: unknown regime $regime for $rel"
  return 3
}

# Full path check for a skill's write. Prints the regime when allowed.
gate_check_path() {
  local skill="$1" target="$2" vault="$3" rel regime
  if ! rel="$(gate_relpath "$target" "$vault")"; then
    echo "refused: $target is outside the vault or contains '..'"
    return 3
  fi
  regime="$(gate_regime "$vault" "$rel")"
  gate_skill_allows "$skill" "$regime" "$rel" || return 3
  printf '%s %s\n' "$regime" "$rel"
}

# One line per task line: "<id or ->\t<task text without its metadata>".
gate_task_lines() {
  LC_ALL=C awk '
    BEGIN {
      id = "\360\237\206\224"
      n = split("\360\237\224\272 \342\217\253 \360\237\224\274 \360\237\224\275 \342\217\254 \360\237\223\205 \342\217\263 \360\237\233\253 \342\234\205 \342\235\214 \360\237\224\201 " id, glyphs, " ")
    }
    /^[ \t]*[-*+] \[.\] / {
      line = $0
      sub(/^[ \t]*[-*+] \[.\] /, "", line)
      cut = length(line) + 1
      for (g = 1; g <= n; g++) {
        i = index(line, glyphs[g])
        if (i > 0 && i < cut) cut = i
      }
      text = substr(line, 1, cut - 1)
      sub(/[ \t\r]+$/, "", text)
      rest = line
      found = 0
      while ((i = index(rest, id)) > 0) {
        rest = substr(rest, i + length(id))
        sub(/^[ \t]+/, "", rest)
        tok = rest
        sub(/[ \t\r].*$/, "", tok)
        if (tok == "") tok = "(empty)"
        print tok "\t" text
        found = 1
      }
      if (!found) print "-\t" text
    }
  ' "$1"
}

# The UUID preservation rule. $1 is the file as it is now, $2 as it would become.
# Prints one line per violation and returns 1 if there are any.
#
#   - every ID on the before side stays, byte for byte, on exactly one task line
#   - an ID may not move onto another task's text (a swap)
#   - no ID appears that was not there before: W1 is the only thing that mints,
#     and its parser only matches m-[0-9a-f]{8}
#   - a new task with no ID is fine, W1 gives it one on the next sync
gate_check_task_ids() {
  local before="$1" after="$2" tmp out
  tmp="$(mktemp -d -t mogging-gate.XXXXXX)" || return 2
  : > "$tmp/before"
  [ -f "$before" ] && gate_task_lines "$before" > "$tmp/before"
  gate_task_lines "$after" > "$tmp/after"
  out="$(LC_ALL=C awk -F '\t' '
    FILENAME == ARGV[1] {
      if ($1 != "-") { bcount[$1]++; btext[$1] = $2; textid[$2] = $1 }
      next
    }
    {
      if ($1 == "-") { noid[$2] = 1; next }
      acount[$1]++
      if (!($1 in atext)) atext[$1] = $2
      aid[$2] = $1
    }
    END {
      for (id in bcount) {
        if (!(id in acount)) {
          t = btext[id]
          if (t in noid)      print "dropped: \"" t "\" lost its ID " id
          else if (t in aid)  print "rewritten: \"" t "\" changed ID from " id " to " aid[t]
          else                print "removed: the task with ID " id " (\"" t "\") is gone"
        } else if (atext[id] != btext[id] && (atext[id] in textid) && textid[atext[id]] != id) {
          print "swapped: ID " id " now sits on \"" atext[id] "\", which belonged to " textid[atext[id]]
        }
      }
      for (id in acount) {
        if (acount[id] > 1 && acount[id] > bcount[id]) print "duplicated: ID " id " is on " acount[id] " task lines"
        if (!(id in bcount)) {
          if (id !~ /^m-[0-9a-f]+$/ || length(id) != 10)
            print "self-minted: " id " is not m-XXXXXXXX, and the W1 parser would silently ignore it. Leave the ID off, W1 mints it."
          else
            print "self-minted: " id " was not in the file. Leave the ID off, W1 mints it."
        }
      }
    }
  ' "$tmp/before" "$tmp/after" | LC_ALL=C sort)"
  rm -rf "$tmp"
  if [ -n "$out" ]; then
    printf '%s\n' "$out"
    return 1
  fi
  return 0
}

# Fails when text holds anything on the repo's secret deny list.
gate_scrub() {
  local text="$1" pat
  # shellcheck disable=SC1091
  . "$GATE_LIB_DIR/../../config/secrets.patterns" || return 1
  for pat in "${HARDBLOCK[@]}"; do
    if printf '%s' "$text" | LC_ALL=C grep -qE -e "$pat"; then
      return 1
    fi
  done
  return 0
}

# Snapshot an existing file before it is overwritten, per the backup non-negotiable.
gate_backup() {
  local vault="$1" rel="$2" stamp_dir dest
  stamp_dir="$vault/Claude-Memory/backups/$(date +%Y-%m-%d)"
  mkdir -p "$stamp_dir" || return 1
  dest="$(mktemp -d "$stamp_dir/$(date +%H%M%S).XXXXXX")" || return 1
  cp -p "$vault/$rel" "$dest/$(printf '%s' "$rel" | sed 's#/#--#g').bak"
}

# Ask before writing. $1 is 1 when --yes was passed. EOF counts as no.
gate_confirm() {
  local yes="$1" answer=""
  [ "$yes" = "1" ] && return 0
  printf 'Proceed? (y/n) '
  IFS= read -r answer || answer=""
  case "$answer" in y|Y|yes|YES) return 0 ;; esac
  return 1
}

gate_vault_dir() {
  if [ -z "${VAULT_DIR:-}" ] || [ ! -d "${VAULT_DIR:-}" ]; then
    echo "VAULT_DIR must point at the vault (or pass --vault PATH)" >&2
    return 2
  fi
  printf '%s\n' "$VAULT_DIR"
}

# Byte offset after a complete YAML frontmatter block. LC_ALL=C counts bytes,
# allowing writers to append the original body without newline normalization.
gate_frontmatter_bytes() {
  LC_ALL=C awk '
    NR == 1 && $0 !~ /^---[ \t\r]*$/ { exit 1 }
    { bytes += length($0) + 1 }
    NR > 1 && /^---[ \t\r]*$/ { print bytes; found = 1; exit }
    END { if (!found) exit 1 }
  ' "$1"
}
