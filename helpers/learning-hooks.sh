#!/bin/bash
# Vendored from FidgetFlo (fidgetcoding/fidgetflo) — a FidgetFlo-internal build
# descended from ruvnet/ruflo@v3.5.80 with additional pattern-graph logic
# extended by <ORG-A>. Upstream: https://github.com/ruvnet/ruflo/tree/v3.5.80
# License:   MIT (c) 2024-2026 ruvnet, (c) 2026 <ORG-A> / the operator
# Synced:    2026-04-20
# See:       docs/CREDITS.md for the full attribution chain + NOTICE for license text.
#
# Claude Flow V3 - Learning Hooks
# Integrates learning-service.mjs with session lifecycle

# Fail-closed on unset vars + pipeline failures. Matches the sibling
# helpers (learning-optimizer.sh, pattern-consolidator.sh) and prevents
# silent partial-failure modes during session-end flush. We intentionally
# do NOT set -e because several branches inspect $? after a command that
# may legitimately fail (learning-service node call with no patterns yet,
# benchmark on empty DB).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LEARNING_SERVICE="$SCRIPT_DIR/learning-service.mjs"
LEARNING_DIR="$PROJECT_ROOT/.claude-flow/learning"
METRICS_DIR="$PROJECT_ROOT/.claude-flow/metrics"

# Ensure directories exist
mkdir -p "$LEARNING_DIR" "$METRICS_DIR"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
DIM='\033[2m'
RESET='\033[0m'

log() { echo -e "${CYAN}[Learning] $1${RESET}"; }
success() { echo -e "${GREEN}[Learning] ✓ $1${RESET}"; }
warn() { echo -e "${YELLOW}[Learning] ⚠ $1${RESET}"; }
error() { echo -e "${RED}[Learning] ✗ $1${RESET}"; }

# Generate session ID
generate_session_id() {
  echo "session_$(date +%Y%m%d_%H%M%S)_$$"
}

***REMOVED***=
# Session Start Hook
***REMOVED***=
session_start() {
  local session_id="${1:-$(generate_session_id)}"

  log "Initializing learning service for session: $session_id"

  # Check if better-sqlite3 is available
  if ! npm list better-sqlite3 --prefix "$PROJECT_ROOT" >/dev/null 2>&1; then
    log "Installing better-sqlite3..."
    # Pinned to caret-major 11.x so a compromised future major can't silently
    # ship on the next opt-in install. Bump the range deliberately when
    # better-sqlite3 releases v12 and you've reviewed the diff.
    npm install --prefix "$PROJECT_ROOT" 'better-sqlite3@^11' --save-dev --silent 2>/dev/null || true
  fi

  # Initialize learning service
  local init_result
  if init_result=$(node "$LEARNING_SERVICE" init "$session_id" 2>&1); then
    # Parse and display stats
    local short_term long_term
    short_term=$(echo "$init_result" | grep -o '"shortTermPatterns":[0-9]*' | cut -d: -f2)
    long_term=$(echo "$init_result" | grep -o '"longTermPatterns":[0-9]*' | cut -d: -f2)

    success "Learning service initialized"
    echo -e "  ${DIM}├─ Short-term patterns: ${short_term:-0}${RESET}"
    echo -e "  ${DIM}├─ Long-term patterns: ${long_term:-0}${RESET}"
    echo -e "  ${DIM}└─ Session ID: $session_id${RESET}"

    # Store session ID for later hooks
    echo "$session_id" > "$LEARNING_DIR/current-session-id"

    # Update metrics
    cat > "$METRICS_DIR/learning-status.json" << EOF
{
  "sessionId": "$session_id",
  "initialized": true,
  "shortTermPatterns": ${short_term:-0},
  "longTermPatterns": ${long_term:-0},
  "hnswEnabled": true,
  "timestamp": "$(date -Iseconds)"
}
EOF

    return 0
  else
    warn "Learning service initialization failed (non-critical)"
    echo "$init_result" | head -5
    return 1
  fi
}

***REMOVED***=
# Session End Hook
***REMOVED***=
session_end() {
  log "Consolidating learning data..."

  # Get session ID
  local session_id=""
  if [ -f "$LEARNING_DIR/current-session-id" ]; then
    session_id=$(cat "$LEARNING_DIR/current-session-id")
  fi

  # Export session data
  local export_result
  if export_result=$(node "$LEARNING_SERVICE" export 2>&1); then
    # Save export
    echo "$export_result" > "$LEARNING_DIR/session-export-$(date +%Y%m%d_%H%M%S).json"

    local patterns
    patterns=$(echo "$export_result" | grep -o '"patterns":[0-9]*' | cut -d: -f2)
    log "Session exported: $patterns patterns"
  fi

  # Run consolidation
  local consolidate_result
  if consolidate_result=$(node "$LEARNING_SERVICE" consolidate 2>&1); then
    local removed pruned duration
    removed=$(echo "$consolidate_result" | grep -o '"duplicatesRemoved":[0-9]*' | cut -d: -f2)
    pruned=$(echo "$consolidate_result" | grep -o '"patternsProned":[0-9]*' | cut -d: -f2)
    duration=$(echo "$consolidate_result" | grep -o '"durationMs":[0-9]*' | cut -d: -f2)

    success "Consolidation complete"
    echo -e "  ${DIM}├─ Duplicates removed: ${removed:-0}${RESET}"
    echo -e "  ${DIM}├─ Patterns pruned: ${pruned:-0}${RESET}"
    echo -e "  ${DIM}└─ Duration: ${duration:-0}ms${RESET}"
  else
    warn "Consolidation failed (non-critical)"
  fi

  # Get final stats
  local stats_result
  if stats_result=$(node "$LEARNING_SERVICE" stats 2>&1); then
    echo "$stats_result" > "$METRICS_DIR/learning-final-stats.json"

    local total_short total_long avg_search
    total_short=$(echo "$stats_result" | grep -o '"shortTermPatterns":[0-9]*' | cut -d: -f2)
    total_long=$(echo "$stats_result" | grep -o '"longTermPatterns":[0-9]*' | cut -d: -f2)
    avg_search=$(echo "$stats_result" | grep -o '"avgSearchTimeMs":[0-9.]*' | cut -d: -f2)

    log "Final stats:"
    echo -e "  ${DIM}├─ Short-term: ${total_short:-0}${RESET}"
    echo -e "  ${DIM}├─ Long-term: ${total_long:-0}${RESET}"
    echo -e "  ${DIM}└─ Avg search: ${avg_search:-0}ms${RESET}"
  fi

  # Clean up session file
  rm -f "$LEARNING_DIR/current-session-id"

  return 0
}

***REMOVED***=
# Store Pattern (called by post-edit hooks)
***REMOVED***=
store_pattern() {
  local strategy="$1"
  local domain="${2:-general}"
  # `quality` is part of the public CLI surface (store <strategy> <domain>
  # <quality>) but the current learning-service.mjs signature only accepts
  # strategy+domain. Keep the positional slot so callers don't break when the
  # service grows a quality arg — shellcheck-disable covers the unused case.
  # shellcheck disable=SC2034
  local quality="${3:-0.7}"

  if [ -z "$strategy" ]; then
    error "No strategy provided"
    return 1
  fi

  # Escape quotes in strategy
  local escaped_strategy="${strategy//\"/\\\"}"

  local result
  if result=$(node "$LEARNING_SERVICE" store "$escaped_strategy" "$domain" 2>&1); then
    local action id
    action=$(echo "$result" | grep -o '"action":"[^"]*"' | cut -d'"' -f4)
    id=$(echo "$result" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)

    if [ "$action" = "created" ]; then
      success "Pattern stored: $id"
    else
      log "Pattern updated: $id"
    fi
    return 0
  else
    warn "Pattern storage failed"
    return 1
  fi
}

***REMOVED***=
# Search Patterns (called by pre-edit hooks)
***REMOVED***=
search_patterns() {
  local query="$1"
  local k="${2:-3}"

  if [ -z "$query" ]; then
    error "No query provided"
    return 1
  fi

  # Escape quotes
  local escaped_query="${query//\"/\\\"}"

  local result
  if result=$(node "$LEARNING_SERVICE" search "$escaped_query" "$k" 2>&1); then
    local patterns search_time
    patterns=$(echo "$result" | grep -o '"patterns":\[' | wc -l)
    search_time=$(echo "$result" | grep -o '"searchTimeMs":[0-9.]*' | cut -d: -f2)

    echo "$result"

    if [ -n "$search_time" ]; then
      log "Search completed in ${search_time}ms"
    fi
    return 0
  else
    warn "Pattern search failed"
    return 1
  fi
}

***REMOVED***=
# Record Pattern Usage (for promotion tracking)
***REMOVED***=
record_usage() {
  local pattern_id="$1"
  local success="${2:-true}"

  if [ -z "$pattern_id" ]; then
    return 1
  fi

  # This would call into the learning service to record usage
  # For now, log it
  log "Recording usage: $pattern_id (success=$success)"
}

***REMOVED***=
# Run Benchmark
***REMOVED***=
run_benchmark() {
  log "Running HNSW benchmark..."

  local result
  if result=$(node "$LEARNING_SERVICE" benchmark 2>&1); then
    local avg_search p95_search improvement
    avg_search=$(echo "$result" | grep -o '"avgSearchMs":"[^"]*"' | cut -d'"' -f4)
    p95_search=$(echo "$result" | grep -o '"p95SearchMs":"[^"]*"' | cut -d'"' -f4)
    improvement=$(echo "$result" | grep -o '"searchImprovementEstimate":"[^"]*"' | cut -d'"' -f4)

    success "HNSW Benchmark Complete"
    echo -e "  ${DIM}├─ Avg search: ${avg_search}ms${RESET}"
    echo -e "  ${DIM}├─ P95 search: ${p95_search}ms${RESET}"
    echo -e "  ${DIM}└─ Estimated improvement: ${improvement}${RESET}"

    echo "$result"
    return 0
  else
    error "Benchmark failed"
    echo "$result"
    return 1
  fi
}

***REMOVED***=
# Get Stats
***REMOVED***=
get_stats() {
  local result
  if result=$(node "$LEARNING_SERVICE" stats 2>&1); then
    echo "$result"
    return 0
  else
    error "Failed to get stats"
    return 1
  fi
}

***REMOVED***=
# Main
***REMOVED***=
case "${1:-help}" in
  "session-start"|"start")
    session_start "$2"
    ;;
  "session-end"|"end")
    session_end
    ;;
  "store")
    store_pattern "$2" "$3" "$4"
    ;;
  "search")
    search_patterns "$2" "$3"
    ;;
  "record-usage"|"usage")
    record_usage "$2" "$3"
    ;;
  "benchmark")
    run_benchmark
    ;;
  "stats")
    get_stats
    ;;
  "help"|"-h"|"--help")
    cat << 'EOF'
Claude Flow V3 Learning Hooks

Usage: learning-hooks.sh <command> [args]

Commands:
  session-start [id]    Initialize learning for new session
  session-end           Consolidate and export session data
  store <strategy>      Store a new pattern
  search <query> [k]    Search for similar patterns
  record-usage <id>     Record pattern usage
  benchmark             Run HNSW performance benchmark
  stats                 Get learning statistics
  help                  Show this help

Examples:
  ./learning-hooks.sh session-start
  ./learning-hooks.sh store "Fix authentication bug" code
  ./learning-hooks.sh search "authentication error" 5
  ./learning-hooks.sh session-end
EOF
    ;;
  *)
    error "Unknown command: $1"
    echo "Use 'learning-hooks.sh help' for usage"
    exit 1
    ;;
esac
