#!/usr/bin/env bash
# Stop hook placeholder. The real /save skill handles conversation capture.
# This hook fires on session end; installs a marker file so /save --from-stop
# can replay if configured. Does NOT auto-save by default.
set -euo pipefail
SESSION_ID="${CLAUDE_SESSION_ID:-$(date +%s)}"
MARKER="${HOME}/.claude/mogging-stop-markers/${SESSION_ID}.marker"
mkdir -p "$(dirname "$MARKER")"
touch "$MARKER"
# Pass through — do not block session end
echo '{"continue": true}'
