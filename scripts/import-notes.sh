#!/usr/bin/env bash
set -uo pipefail

***REMOVED***=
# import-notes.sh
# Import existing notes (Apple Notes, OneNote, Notion, Evernote, raw files)
# into your 2ndBrain-mogging vault. This script prepares the environment
# and stages the files — the /import-notes skill walks Claude through the
# actual categorization into 02-Sources/, 03-Concepts/, 05-Projects/, etc.
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
echo -e "${BLUE}  import-notes — Stage Your Existing Notes${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# -----------------------------------------------------------------------------
# 1. Find the mogged vault
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
# 2. Apple Notes — prompt user to install Exporter.app if on macOS
# -----------------------------------------------------------------------------
echo ""
if [ "$(uname)" = "Darwin" ]; then
    if [ -d "/Applications/Exporter.app" ]; then
        success "Apple Notes Exporter app already installed"
    else
        echo "  ┌─────────────────────────────────────────────────────────┐"
        echo "  │  Apple Notes → Markdown export                          │"
        echo "  │                                                         │"
        echo "  │  Grab 'Exporter' from the Mac App Store:                │"
        echo "  │  https://apps.apple.com/us/app/exporter/id1099120373    │"
        echo "  │                                                         │"
        echo "  │  After installing:                                      │"
        echo "  │  1. Open Exporter.app                                   │"
        echo "  │  2. Pick 'Markdown' as the export format                │"
        echo "  │  3. Export your Notes to ~/Desktop/apple-notes-export/  │"
        echo "  │  4. Rerun this script                                   │"
        echo "  └─────────────────────────────────────────────────────────┘"
        echo ""
        warn "Exporter not installed — skip this step if you have no Apple Notes to import."
    fi
else
    info "Apple Notes export is macOS-only — skipping that check"
fi

# -----------------------------------------------------------------------------
# 3. Check converters
# -----------------------------------------------------------------------------
echo ""
info "Checking file-conversion tooling..."
if command -v pandoc &>/dev/null; then
    success "pandoc available  — handles .docx / .pptx / .html / .rtf / .epub → markdown"
else
    warn "pandoc not found — install via 'brew install pandoc' if you have Word/PowerPoint exports"
fi

if python3 -c "import xlsx2csv" &>/dev/null 2>&1; then
    success "xlsx2csv available — handles Excel spreadsheets"
else
    warn "xlsx2csv not found — install via 'pip3 install xlsx2csv' if you have .xlsx exports"
fi

# -----------------------------------------------------------------------------
# 4. Scan Desktop / Downloads / Documents for exported note files
# -----------------------------------------------------------------------------
echo ""
info "Looking for exported notes in common locations..."
NOTES_FOUND=0
SUMMARY=""

for search_dir in "$HOME/Desktop" "$HOME/Downloads" "$HOME/Documents"; do
    [ -d "$search_dir" ] || continue
    COUNT=$(find "$search_dir" -maxdepth 3 \( \
        -name "*.md" -o -name "*.txt" -o -name "*.docx" -o -name "*.pptx" \
        -o -name "*.xlsx" -o -name "*.html" -o -name "*.htm" -o -name "*.rtf" \
        -o -name "*.enex" -o -name "*.json" \
    \) 2>/dev/null | wc -l | tr -d ' ')
    if [ "$COUNT" -gt 0 ]; then
        info "Found $COUNT candidate file(s) in $search_dir"
        NOTES_FOUND=$((NOTES_FOUND + COUNT))
        SUMMARY="$SUMMARY\n    - $search_dir: $COUNT"
    fi
done

# -----------------------------------------------------------------------------
# 5. Hand off to Claude
# -----------------------------------------------------------------------------
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  Environment ready — hand off to Claude${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  Vault:            $VAULT_PATH"
echo "  Candidate files:  $NOTES_FOUND"
if [ -n "$SUMMARY" ]; then
    echo -e "$SUMMARY"
fi
echo ""
echo "  Supported sources:"
echo "    Apple Notes        (via Exporter.app → markdown)"
echo "    OneNote            (export to .docx → pandoc)"
echo "    Notion             (official export → markdown + csv)"
echo "    Evernote           (.enex files)"
echo "    Raw files          (.md / .txt / .docx / .pptx / .xlsx / .html / .rtf)"
echo ""
echo "  In Claude Code, run:"
echo ""
echo "    /import-notes"
echo ""
echo "  …and point it at the folder holding your exports. The skill will:"
echo "    - Convert non-markdown files via pandoc / xlsx2csv"
echo "    - Validate each file (skip empty / corrupt)"
echo "    - Route factual content into 02-Sources/"
echo "    - Split atomic ideas into 03-Concepts/"
echo "    - Tether project-tied material into 05-Projects/<project>/"
echo "    - Ask you before touching anything (dry-run preview first)"
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
