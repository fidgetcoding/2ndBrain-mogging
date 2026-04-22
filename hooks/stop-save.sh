#!/usr/bin/env bash
# Stop hook placeholder. The real /save skill handles conversation capture.
# This hook fires on session end; installs a marker file so /save --from-stop
# can replay if configured. Does NOT auto-save by default.
set -euo pipefail
# Defense-in-depth: Claude Code owns CLAUDE_SESSION_ID, but sanitize anyway
# so a malformed value (e.g. containing '/' or '..') cannot escape the
# marker directory. Keep only ASCII alphanumerics, dashes, and underscores.
SESSION_ID_RAW="${CLAUDE_SESSION_ID:-$(date +%s)}"
SESSION_ID="${SESSION_ID_RAW//[^A-Za-z0-9_-]/}"
if [[ -z "$SESSION_ID" ]]; then
  SESSION_ID="$(date +%s)"
fi
MARKER="${HOME}/.claude/mogging-stop-markers/${SESSION_ID}.marker"
mkdir -p "$(dirname "$MARKER")"
touch "$MARKER"
# Pass through — do not block session end
echo '{"continue": true}'
