#!/usr/bin/env bash
set -uo pipefail

***REMOVED***=
# import-claude.sh
# Import a Claude.ai (or ChatGPT) data export into your 2ndBrain-mogging vault.
# Unzips the export to a staging area and hands the parsing off to Claude
# itself — the /import-claude skill walks you through the rest.
***REMOVED***=

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
fail()    { echo -e "${RED}[FAIL]${NC} $1"; exit 1; }

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  import-claude — Stage Claude / ChatGPT Export${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# -----------------------------------------------------------------------------
# 1. Find the 2ndBrain-mogging vault
#    Looks for the post-mogging marker (02-Sources/ + 05-Projects/ + CLAUDE.md)
# -----------------------------------------------------------------------------
VAULT_PATH="${VAULT_PATH:-}"
is_mogged_vault() {
    [ -d "$1/02-Sources" ] && [ -d "$1/05-Projects" ] && [ -f "$1/CLAUDE.md" ]
}

if [ -z "$VAULT_PATH" ]; then
    for candidate in \
        "$HOME/Desktop/BRAIN" \
        "$HOME/Desktop/BRAIN2" \
        "$HOME/Desktop/2ndBrain" \
        "$HOME/Desktop/Second-Brain" \
        "$HOME/Documents/BRAIN" \
        "$HOME/Documents/2ndBrain"; do
        if is_mogged_vault "$candidate"; then
            VAULT_PATH="$candidate"
            break
        fi
    done
    if [ -z "$VAULT_PATH" ]; then
        FOUND=$(find "$HOME/Desktop" "$HOME/Documents" -maxdepth 5 -name "02-Sources" -type d 2>/dev/null | head -1)
        if [ -n "$FOUND" ]; then
            CANDIDATE="$(dirname "$FOUND")"
            is_mogged_vault "$CANDIDATE" && VAULT_PATH="$CANDIDATE"
        fi
    fi
fi

if [ -z "$VAULT_PATH" ] || ! is_mogged_vault "$VAULT_PATH"; then
    fail "Couldn't find a mogged vault (needs 02-Sources/, 05-Projects/, CLAUDE.md). Install 2ndBrain-mogging first, or set VAULT_PATH=/absolute/path/to/vault."
fi

success "Vault found at: $VAULT_PATH"

# -----------------------------------------------------------------------------
# 2. Find the export zip
#    Supports Claude.ai (data-<uuid>-batch-<n>.zip) and ChatGPT (chatgpt-*.zip)
# -----------------------------------------------------------------------------
echo ""
info "Looking for a Claude / ChatGPT data export..."

find_export_zip() {
    if [ -n "${EXPORT_ZIP:-}" ] && [ -f "$EXPORT_ZIP" ]; then
        echo "$EXPORT_ZIP"
        return 0
    fi
    if [ -n "${CLAUDE_ZIP:-}" ] && [ -f "$CLAUDE_ZIP" ]; then
        echo "$CLAUDE_ZIP"
        return 0
    fi

    local search_dirs="$HOME/Downloads $HOME/Desktop $HOME/Documents"
    for dir in $search_dirs; do
        [ -d "$dir" ] || continue
        local found
        # Claude.ai export pattern
        found=$(find "$dir" -maxdepth 2 -name "data-*-batch-*.zip" -type f 2>/dev/null | sort -r | head -1)
        [ -n "$found" ] && { echo "$found"; return 0; }
        # ChatGPT export pattern
        found=$(find "$dir" -maxdepth 2 -iname "chatgpt*.zip" -type f 2>/dev/null | sort -r | head -1)
        [ -n "$found" ] && { echo "$found"; return 0; }
        # Generic fallbacks
        found=$(find "$dir" -maxdepth 2 -iname "*claude*.zip" -type f 2>/dev/null | sort -r | head -1)
        [ -n "$found" ] && { echo "$found"; return 0; }
        found=$(find "$dir" -maxdepth 2 -iname "*anthropic*.zip" -type f 2>/dev/null | sort -r | head -1)
        [ -n "$found" ] && { echo "$found"; return 0; }
        found=$(find "$dir" -maxdepth 2 -iname "*openai*.zip" -type f 2>/dev/null | sort -r | head -1)
        [ -n "$found" ] && { echo "$found"; return 0; }
    done
    return 1
}

ZIP_PATH=$(find_export_zip)
if [ -z "$ZIP_PATH" ]; then
    echo ""
    warn "No export zip found."
    echo ""
    echo -e "  ${YELLOW}Option 1 — Point the script at a specific zip${NC}"
    echo "    export EXPORT_ZIP=/path/to/your/export.zip"
    echo "    bash scripts/import-claude.sh"
    echo ""
    echo -e "  ${YELLOW}Option 2 — Drop the zip into ~/Downloads/ and rerun${NC}"
    echo "    Claude.ai exports look like: data-<uuid>-batch-1.zip"
    echo "    ChatGPT exports look like:   chatgpt-<date>.zip"
    echo ""
    echo -e "  ${YELLOW}Haven't exported yet?${NC}"
    echo "    Claude.ai: Settings → Privacy → 'Download my data'"
    echo "    ChatGPT:   Settings → Data controls → 'Export data'"
    echo "    Either one emails you a download link — save the zip to ~/Downloads/."
    echo ""
    exit 1
fi
success "Found export: $ZIP_PATH"

# -----------------------------------------------------------------------------
# 3. Extract to staging
# -----------------------------------------------------------------------------
STAGING="$VAULT_PATH/.import-staging/$(date +%Y%m%d-%H%M%S)-claude"
mkdir -p "$STAGING"

info "Extracting export to staging..."
if ! unzip -qo "$ZIP_PATH" -d "$STAGING" 2>/dev/null; then
    fail "Failed to extract $ZIP_PATH — is the zip file valid?"
fi
success "Extracted to: $STAGING"

CONV_COUNT=$(find "$STAGING" -type f \( -name "*.json" -o -name "*.txt" -o -name "*.md" -o -name "*.html" \) 2>/dev/null | wc -l | tr -d ' ')
info "Found $CONV_COUNT candidate files"

# -----------------------------------------------------------------------------
# 4. Hand off to Claude
# -----------------------------------------------------------------------------
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  Staging complete — hand off to Claude${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  Vault:       $VAULT_PATH"
echo "  Staging:     $STAGING"
echo "  Candidates:  $CONV_COUNT"
echo ""
echo "  In Claude Code, run:"
echo ""
echo "    /import-claude"
echo ""
echo "  …and point it at the staging path above. The skill will:"
echo "    - Sort conversations by their source Claude Project (or topic)"
echo "    - Route each into 01-Conversations/<project-mirror>/ as full-fidelity captures"
echo "    - Mirror each as a factual LIT-* note in 02-Sources/"
echo "    - Spawn linked concept stubs in 03-Concepts/ where ideas repeat"
echo "    - Update 04-Index/ + 05-Projects/<project>/ backlinks"
echo ""
echo "  If you prefer manual control, /backfill handles the same payload as a"
echo "  /save loop — slower but shows every write."
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
