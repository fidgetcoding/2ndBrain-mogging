#!/usr/bin/env bash
#
# 2ndBrain-mogging — doctor
#
# Sanity-check that the install is healthy:
#   - every symlink under ~/.claude/{skills,commands,agents}/ resolves
#   - every plist shipped in scheduled/launchd/ is installed and loaded
#   - the plugin is reachable (via symlinks — Claude's plugin registry is
#     forward-looking; install.sh does not call `claude plugin add`)
#
# Exit codes:
#   0 = all green
#   3 = one or more checks reported FAIL (intentionally non-standard so
#       callers using doctor.sh as a CI gate can distinguish real FAILs
#       from shell errors like "file not found" or "permission denied")
#

set -euo pipefail
IFS=$'\n\t'

SCRIPT_PATH="${BASH_SOURCE[0]}"
while [[ -L "$SCRIPT_PATH" ]]; do
  SCRIPT_DIR="$(cd -P "$(dirname "$SCRIPT_PATH")" >/dev/null 2>&1 && pwd)"
  SCRIPT_PATH="$(readlink "$SCRIPT_PATH")"
  [[ "$SCRIPT_PATH" != /* ]] && SCRIPT_PATH="$SCRIPT_DIR/$SCRIPT_PATH"
done
BIN_DIR="$(cd -P "$(dirname "$SCRIPT_PATH")" >/dev/null 2>&1 && pwd)"
REPO_ROOT="$(cd -P "$BIN_DIR/.." >/dev/null 2>&1 && pwd)"

CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
LAUNCHAGENTS_DIR="$HOME/Library/LaunchAgents"

# Vault path is discovered at runtime from the statusline marker that
# install.sh step 10.8 writes (~/.claude/.mogging-vault). Falls back to
# the $VAULT environment variable if it's set, then to empty (in which
# case vault-scoped checks are skipped with [doctor:info], not failed —
# doctor on a non-vault host is a valid scenario).
MOGGING_VAULT_MARKER="$CLAUDE_HOME/.mogging-vault"
VAULT_PATH=""
if [[ -f "$MOGGING_VAULT_MARKER" ]]; then
  # Marker contains a single line: the absolute vault path.
  VAULT_PATH="$(head -n 1 "$MOGGING_VAULT_MARKER" 2>/dev/null | tr -d '\r\n' || true)"
fi
if [[ -z "$VAULT_PATH" && -n "${VAULT:-}" ]]; then
  VAULT_PATH="$VAULT"
fi

FAIL_COUNT=0
# Exit code for "one or more FAILs fired" — non-standard on purpose so
# callers can distinguish a real health-check failure (exit 3) from
# shell plumbing errors (exit 1/2/127/etc).
DOCTOR_FAIL_EXIT=3

pass() { printf '[doctor:ok]   %s\n' "$*"; }
fail() { printf '[doctor:FAIL] %s\n' "$*" >&2; FAIL_COUNT=$((FAIL_COUNT + 1)); }
info() { printf '[doctor:info] %s\n' "$*"; }

# ---- symlink checks ---------------------------------------------------------

check_symlinks_for_kind() {
  local kind="$1"
  local src_root="$REPO_ROOT/$kind"
  local dest_root="$CLAUDE_HOME/$kind"
  info "checking $kind symlinks"
  [[ -d "$src_root" ]] || { info "no $kind in repo; skipping"; return 0; }
  shopt -s nullglob
  local entry name dest target
  for entry in "$src_root"/*; do
    name="$(basename "$entry")"
    dest="$dest_root/$name"
    if [[ ! -L "$dest" ]]; then
      fail "not a symlink: $dest"
      continue
    fi
    target="$(readlink "$dest" 2>/dev/null || true)"
    if [[ "$target" != "$entry" ]]; then
      fail "$dest -> $target (expected $entry)"
      continue
    fi
    if [[ ! -e "$dest" ]]; then
      fail "dangling symlink: $dest"
      continue
    fi
    pass "$kind/$name"
  done
  shopt -u nullglob
}

# ---- launchd checks ---------------------------------------------------------

check_launchd() {
  info "checking launchd jobs"
  local src_dir="$REPO_ROOT/scheduled/launchd"
  [[ -d "$src_dir" ]] || { info "no launchd sources; skipping"; return 0; }
  shopt -s nullglob
  local plist name dest label
  for plist in "$src_dir"/*.plist; do
    name="$(basename "$plist")"
    dest="$LAUNCHAGENTS_DIR/$name"
    if [[ ! -f "$dest" ]]; then
      fail "plist not installed: $dest"
      continue
    fi
    # extract label without a plist-only tool — grep the literal <string>
    label="$(awk '/<key>Label<\/key>/{getline; sub(/.*<string>/,""); sub(/<\/string>.*/,""); print; exit}' "$dest")"
    if [[ -z "$label" ]]; then
      fail "could not determine Label in $dest"
      continue
    fi
    if launchctl list 2>/dev/null | awk '{print $3}' | grep -qx "$label"; then
      pass "launchd loaded: $label"
    else
      fail "launchd not loaded: $label (file present at $dest)"
    fi
  done
  shopt -u nullglob
}

# ---- plugin registration -----------------------------------------------------

check_plugin_registered() {
  info "checking plugin registration (forward-looking)"
  if ! command -v claude >/dev/null 2>&1; then
    fail "claude CLI not on PATH"
    return
  fi
  # read plugin name from .claude-plugin/plugin.json if present
  local plugin_name=""
  if [[ -f "$REPO_ROOT/.claude-plugin/plugin.json" ]] && command -v jq >/dev/null 2>&1; then
    plugin_name="$(jq -r '.name // empty' "$REPO_ROOT/.claude-plugin/plugin.json" 2>/dev/null || true)"
  fi
  if [[ -z "$plugin_name" ]]; then
    plugin_name="2ndbrain-mogging"
  fi
  # NOTE: install.sh does NOT call `claude plugin add` — it wires skills/
  # commands/agents directly as symlinks under ~/.claude/. The plugin
  # registry check here is forward-looking: if Claude's `plugin list`
  # happens to show us, great; if not, that's expected today, not a FAIL.
  # Source of truth is the symlink checks above.
  if claude plugin list 2>/dev/null | grep -q "$plugin_name"; then
    pass "plugin registered (bonus): $plugin_name"
  else
    info "plugin not registered via 'claude plugin list' (expected — install.sh uses symlinks, not plugin registry): $plugin_name"
  fi
}

# ---- npm cache ownership check (WAGMI install-call 2026-04-22 item 7) -------
#
# obsidian-mcp / magic-mcp / any npx-driven MCP fails silently when ~/.npm is
# root-owned (legacy `sudo npm install` damage). Doctor surfaces this with the
# literal one-liner that fixes it — DO NOT print "npm cache fix" (not a real
# subcommand; see WAGMI install-call item 6). The fix is always:
#
#     sudo chown -R $(whoami) ~/.npm
#
# Note: -maxdepth 2 keeps the find cheap on huge ~/.npm caches; root-owned
# damage from a legacy `sudo npm install` lands at the top levels, not deep.

check_npm_cache_ownership() {
  info "checking ~/.npm cache ownership"
  local npm_dir="$HOME/.npm"
  if [[ ! -d "$npm_dir" ]]; then
    info "no ~/.npm directory yet (npm/npx not run); skipping"
    return 0
  fi
  # Use -print -quit to bail at the first hit — we don't need a full listing,
  # we just need to know whether ANY root-owned file lives in the top of the
  # cache. 2>/dev/null swallows permission-denied noise from inaccessible subdirs.
  if find "$npm_dir" -maxdepth 2 -user root -print -quit 2>/dev/null | grep -q .; then
    # Tildes below are LITERAL display text shown to the user — they need to
    # see "~/.npm" so they can paste it into their shell, not "$HOME/.npm".
    # shellcheck disable=SC2088
    fail "~/.npm contains root-owned files (legacy 'sudo npm install' damage)"
    fail "fix with this exact command (copy/paste — no shell substitution gotchas):"
    fail "    sudo chown -R \$(whoami) ~/.npm"
    fail "or, if even that hits a substitution issue, the fully literal form:"
    fail "    sudo chown -R $(whoami):staff ~/.npm"
  else
    # shellcheck disable=SC2088
    pass "~/.npm cache ownership clean (no root-owned files in top 2 levels)"
  fi
}

# ---- vault project-index filename=foldername check (item 9) -----------------
#
# Hard rule from CLAUDE.md: every project folder under 01-Projects/ must have
# an index note where filename = foldername (e.g. PARZVL/PARZVL.md, never
# PARZVL/PARZVL-Index.md). Folder renames (e.g. example-project-1 →
# NiFe-WARS-Kostas) leave the inner .md unchanged, breaking [[PROJECT]]
# wikilink resolution. Surface drift, suggest the rename, never auto-rename
# (project index files are owner=human; CLAUDE.md forbids auto-rewrite).

check_project_filename_equals_folder() {
  info "checking 01-Projects/<folder>/<folder>.md filename-equals-foldername rule"
  if [[ -z "$VAULT_PATH" ]]; then
    info "no vault path discovered (marker $MOGGING_VAULT_MARKER missing); skipping"
    return 0
  fi
  local projects_dir="$VAULT_PATH/05-Projects"
  if [[ ! -d "$projects_dir" ]]; then
    info "$projects_dir not found; skipping (vault may not be a mogged vault yet)"
    return 0
  fi
  shopt -s nullglob
  local folder name expected_index local_fail=0
  for folder in "$projects_dir"/*/; do
    # Strip trailing slash → bare folder name
    name="$(basename "$folder")"
    expected_index="${folder%/}/${name}.md"
    if [[ -f "$expected_index" ]]; then
      pass "01-Projects/$name/$name.md"
    else
      # Look for any .md inside the folder so we can suggest a rename
      shopt -s nullglob
      local candidates=( "${folder}"*.md )
      shopt -u nullglob
      if [[ ${#candidates[@]} -gt 0 ]]; then
        local first
        first="$(basename "${candidates[0]}")"
        fail "01-Projects/$name/ missing $name.md (found ${first} — rename it: mv \"${candidates[0]}\" \"$expected_index\")"
      else
        fail "01-Projects/$name/ missing $name.md (no .md files inside the folder at all — create one or remove the empty folder)"
      fi
      local_fail=1
    fi
  done
  shopt -u nullglob
  if [[ "$local_fail" -eq 0 ]]; then
    pass "all 01-Projects/ folders satisfy filename=foldername"
  fi
}

# ---- Projects-Index.md stale wikilink check (item 10) -----------------------
#
# Projects-Index.md keeps placeholder wikilinks for deleted example projects,
# leaving ghost nodes in graph view. Surface stale wikilinks, but DO NOT
# auto-delete (vault hard rule: "Never remove a note or wikilink without
# flagging it for the human first").

check_projects_index_stale_wikilinks() {
  info "checking 04-Index/Projects-Index.md for stale wikilinks"
  if [[ -z "$VAULT_PATH" ]]; then
    info "no vault path discovered; skipping"
    return 0
  fi
  local index_file="$VAULT_PATH/04-Index/Projects-Index.md"
  if [[ ! -f "$index_file" ]]; then
    info "$index_file not found; skipping"
    return 0
  fi
  local projects_dir="$VAULT_PATH/05-Projects"
  if [[ ! -d "$projects_dir" ]]; then
    info "$projects_dir not found; skipping"
    return 0
  fi
  # Extract candidate wikilink targets. We want the substring between [[ and
  # the first | or ]] — the target, not the alias. grep + sed handles this
  # without pulling in awk regex juggling.
  local stale_count=0
  while IFS= read -r target; do
    [[ -z "$target" ]] && continue
    # Strip any heading anchor (#section) or block ref (^id) — they don't
    # change which file the link resolves to.
    local file_target="${target%%#*}"
    file_target="${file_target%%^*}"
    [[ -z "$file_target" ]] && continue
    # Skip well-known non-project wikilinks (other index hubs, common refs).
    case "$file_target" in
      Projects-Index|Home-Index|Tech-Index|Poetry-Index|Index|TASKS|GITHUB|LORECRAFT-HQ) continue ;;
    esac
    if [[ ! -f "$projects_dir/$file_target/$file_target.md" ]]; then
      fail "Projects-Index.md links to [[$file_target]] but 01-Projects/$file_target/$file_target.md is missing"
      fail "  flag for human review (do NOT auto-delete; CLAUDE.md hard rule)"
      stale_count=$((stale_count + 1))
    fi
  done < <(grep -oE '\[\[[^]|]+' "$index_file" | sed 's/^\[\[//')
  if [[ "$stale_count" -eq 0 ]]; then
    pass "Projects-Index.md wikilinks all resolve to existing project folders"
  fi
}

main() {
  check_symlinks_for_kind "skills"
  check_symlinks_for_kind "commands"
  check_symlinks_for_kind "agents"
  check_launchd
  check_plugin_registered
  check_npm_cache_ownership
  check_project_filename_equals_folder
  check_projects_index_stale_wikilinks
  if [[ "$FAIL_COUNT" -eq 0 ]]; then
    printf '[doctor] all checks passed\n'
    exit 0
  fi
  printf '[doctor] %d check(s) FAILED — exiting %d\n' "$FAIL_COUNT" "$DOCTOR_FAIL_EXIT" >&2
  exit "$DOCTOR_FAIL_EXIT"
}

main "$@"
