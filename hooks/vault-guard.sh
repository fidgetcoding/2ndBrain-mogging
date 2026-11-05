#!/usr/bin/env bash
# hooks/vault-guard.sh: optional PreToolUse hook for Write, Edit and MultiEdit.
# Off unless install.sh --with-guard wrote ~/.claude/.mogging-guard, which holds
# the vault path. Exit 2 blocks the tool call and shows Claude the reason. Any
# other exit lets it through, so a broken hook can't wedge a session.
#
#   vault-guard.sh               the UUID rule, on every edit under 04-Tasks/
#   vault-guard.sh --skill wiki  plus that skill's scope rules. /wiki and
#                                /autoresearch register this from their
#                                frontmatter. Claude Code keeps a skill's hooks
#                                for the rest of the session, so tasks stay
#                                locked until a new session.
set -u

SELF="$0"
while [ -L "$SELF" ]; do
  link="$(readlink "$SELF")"
  case "$link" in /*) SELF="$link" ;; *) SELF="$(dirname "$SELF")/$link" ;; esac
done
ROOT="$(cd -P "$(dirname "$SELF")/.." && pwd)"
# shellcheck source=bin/lib/vault-gate.sh
. "$ROOT/bin/lib/vault-gate.sh"

skill=""
[ "${1:-}" = "--skill" ] && skill="${2:-}"

marker="${CLAUDE_HOME:-$HOME/.claude}/.mogging-guard"
[ -f "$marker" ] || exit 0
vault="$(head -n1 "$marker")"
[ -d "$vault" ] || exit 0
command -v jq >/dev/null 2>&1 || { echo "vault-guard: jq not found, not checking" >&2; exit 1; }

input="$(cat)"
file="$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)" || {
  echo "vault-guard: could not parse hook input, not checking" >&2
  exit 1
}
[ -n "$file" ] || exit 0

block() {
  printf 'Blocked by the vault guard: %s\n' "$1" >&2
  exit 2
}

rel="$(gate_relpath "$file" "$vault")" || {
  # A ".." that still lands inside the vault must not slip past as "outside".
  case "/$file/" in */../*) block "$file contains '..'" ;; esac
  exit 0
}
regime="$(gate_regime "$vault" "$rel")"

if [ -n "$skill" ]; then
  reason="$(gate_skill_allows "$skill" "$regime" "$rel")" || block "$reason"
fi

[ "$regime" = "SYNC" ] || exit 0
case "$rel" in *.md|*.MD) ;; *) exit 0 ;; esac

tmp="$(mktemp -d -t mogging-guard.XXXXXX)" || exit 1
trap 'rm -rf "$tmp"' EXIT
current="$vault/$rel"
: > "$tmp/current"
[ -f "$current" ] && cp "$current" "$tmp/current"

# What the file would hold after this tool call. jq's one-argument split() takes a
# literal string, and index offsets are avoided because jq 1.6 counts them in bytes.
# shellcheck disable=SC2016
if ! printf '%s' "$input" | jq -j --rawfile cur "$tmp/current" '
    def replace_literal($old; $new; $all):
      if $old == "" then $new
      else split($old) as $parts
        | if ($parts | length) < 2 then .
          elif $all then $parts | join($new)
          else $parts[0] + $new + ($parts[1:] | join($old))
          end
      end;
    .tool_input as $t
    | if .tool_name == "Write" then $t.content
      elif .tool_name == "Edit" then
        $cur | replace_literal($t.old_string; $t.new_string; ($t.replace_all // false))
      elif .tool_name == "MultiEdit" then
        reduce ($t.edits // [])[] as $e ($cur;
          replace_literal($e.old_string; $e.new_string; ($e.replace_all // false)))
      else $cur end
  ' > "$tmp/after" 2>/dev/null; then
  echo "vault-guard: could not compute the edit, not checking" >&2
  exit 1
fi

if ! violations="$(gate_check_task_ids "$current" "$tmp/after")"; then
  block "this edit to $rel breaks the task ID rule. The 🆔 is the join key for the two-way sync, so it stays byte-for-byte.
$violations
Fix the edit. If you really mean to remove or move a task, a human does that in Obsidian."
fi
exit 0
