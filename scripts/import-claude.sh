#!/usr/bin/env bash
set -uo pipefail

***REMOVED***=
# import-claude.sh
# Import a Claude.ai (or ChatGPT) data export into your 2ndBrain-mogging vault.
# Unzips the export to a staging area and hands the parsing off to Claude
# itself — the /import-claude skill walks you through the rest.
#
# Flags (see --help for the full list):
#   --dry-run           Report what would happen without extracting anything.
#   --yes               Skip the interactive confirmation prompt.
#   --export-zip PATH   Use this zip instead of auto-discovery.
#   --vault PATH        Use this vault instead of auto-discovery.
#   --help, -h          Print usage and exit.
#
# Exit codes:
#   0 — success (including dry-run)
#   1 — user-facing runtime error (no vault, no zip, extraction failed, etc.)
#   2 — usage error (unknown flag, missing flag value)
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

usage() {
    cat <<'USAGE'
import-claude.sh — stage a Claude.ai or ChatGPT data export for the /import-claude skill

USAGE:
    bash scripts/import-claude.sh [OPTIONS]
    bash <(curl -fsSL https://…/import-claude.sh) [OPTIONS]

OPTIONS:
    --dry-run              Show what would happen. No staging dir, no unzip.
    --yes, -y              Auto-confirm the extraction prompt (non-interactive).
    --export-zip PATH      Path to the export zip. Overrides auto-discovery.
                           (Also honored via EXPORT_ZIP / CLAUDE_ZIP env vars.)
    --vault PATH           Path to your mogged vault. Overrides auto-discovery.
                           (Also honored via VAULT_PATH env var.)
    -h, --help             Print this help and exit.

FLOW:
    1. Resolve the vault:
         a. --vault PATH          (explicit)
         b. VAULT_PATH env var    (explicit)
         c. Auto-discover common locations (~/BRAIN2, ~/Desktop/2ndBrain, …)
            and confirm which one was picked if more than one candidate matched.
    2. Resolve the export zip:
         a. --export-zip PATH
         b. EXPORT_ZIP / CLAUDE_ZIP env vars
         c. Auto-discover in ~/Downloads, ~/Desktop, ~/Documents
            (Claude.ai: data-*-batch-*.zip   ChatGPT: chatgpt*.zip).
    3. Confirm with the user (unless --yes or --dry-run).
         - If stdin is not a TTY, abort and instruct to pass --dry-run or --yes.
    4. Extract to: <VAULT>/.import-staging/<YYYYMMDD-HHMMSS>-claude/
    5. Print the handoff block pointing at /import-claude.

EXIT CODES:
    0   success (including dry-run)
    1   runtime error (no vault, no zip, extract failed, piped stdin w/o --yes)
    2   usage error  (unknown flag, missing flag value)

EXAMPLES:
    # Fully automatic:
    bash scripts/import-claude.sh --yes

    # Preview only:
    bash scripts/import-claude.sh --dry-run

    # Specific zip + specific vault:
    bash scripts/import-claude.sh \
        --export-zip ~/Downloads/data-abc-batch-1.zip \
        --vault ~/BRAIN2 --yes
USAGE
}

# -----------------------------------------------------------------------------
# Argument parser
# -----------------------------------------------------------------------------
DRY_RUN=0
ASSUME_YES=0
VAULT_PATH="${VAULT_PATH:-}"
EXPORT_ZIP_ARG=""

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        --yes|-y)
            ASSUME_YES=1
            shift
            ;;
        --export-zip)
            if [ $# -lt 2 ] || [ -z "${2:-}" ]; then
                echo "error: --export-zip requires a PATH argument" >&2
                exit 2
            fi
            EXPORT_ZIP_ARG="$2"
            shift 2
            ;;
        --export-zip=*)
            EXPORT_ZIP_ARG="${1#--export-zip=}"
            shift
            ;;
        --vault)
            if [ $# -lt 2 ] || [ -z "${2:-}" ]; then
                echo "error: --vault requires a PATH argument" >&2
                exit 2
            fi
            VAULT_PATH="$2"
            shift 2
            ;;
        --vault=*)
            VAULT_PATH="${1#--vault=}"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --)
            shift
            break
            ;;
        -*)
            echo "error: unknown flag: $1" >&2
            echo "run 'bash scripts/import-claude.sh --help' for usage" >&2
            exit 2
            ;;
        *)
            echo "error: unexpected positional arg: $1" >&2
            echo "run 'bash scripts/import-claude.sh --help' for usage" >&2
            exit 2
            ;;
    esac
done

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  import-claude — Stage Claude / ChatGPT Export${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
if [ "$DRY_RUN" -eq 1 ]; then
    echo -e "${YELLOW}  (dry-run — no files will be written)${NC}"
fi
echo ""

# -----------------------------------------------------------------------------
# 1. Resolve the vault
#    Priority: --vault flag > VAULT_PATH env > auto-discovery
# -----------------------------------------------------------------------------
is_mogged_vault() {
    [ -d "$1/02-Sources" ] && [ -d "$1/01-Projects" ] && [ -f "$1/CLAUDE.md" ]
}

VAULT_SOURCE="auto-discovery"
if [ -n "$VAULT_PATH" ]; then
    VAULT_SOURCE="explicit (--vault / VAULT_PATH)"
fi

if [ -z "$VAULT_PATH" ]; then
    VAULT_CANDIDATES=()
    # Home-dir candidates first — they're the documented recommendation
    # (~/BRAIN2; Desktop/Documents are TCC-protected on modern macOS).
    for candidate in \
        "$HOME/BRAIN2" \
        "$HOME/BRAIN" \
        "$HOME/2ndBrain" \
        "$HOME/Second-Brain" \
        "$HOME/Desktop/BRAIN" \
        "$HOME/Desktop/BRAIN2" \
        "$HOME/Desktop/2ndBrain" \
        "$HOME/Desktop/Second-Brain" \
        "$HOME/Documents/BRAIN" \
        "$HOME/Documents/2ndBrain"; do
        if is_mogged_vault "$candidate"; then
            VAULT_CANDIDATES+=("$candidate")
        fi
    done

    # Fallback: scan up to depth 5 in Desktop/Documents for a 02-Sources marker
    if [ "${#VAULT_CANDIDATES[@]}" -eq 0 ]; then
        while IFS= read -r found; do
            [ -n "$found" ] || continue
            CANDIDATE="$(dirname "$found")"
            if is_mogged_vault "$CANDIDATE"; then
                VAULT_CANDIDATES+=("$CANDIDATE")
            fi
        done < <(find "$HOME/Desktop" "$HOME/Documents" -maxdepth 5 -name "02-Sources" -type d 2>/dev/null)
    fi

    if [ "${#VAULT_CANDIDATES[@]}" -eq 0 ]; then
        fail "Couldn't find a mogged vault (needs 02-Sources/, 01-Projects/, CLAUDE.md). Install 2ndBrain-mogging first, or pass --vault /absolute/path/to/vault."
    elif [ "${#VAULT_CANDIDATES[@]}" -eq 1 ]; then
        VAULT_PATH="${VAULT_CANDIDATES[0]}"
        info "Auto-discovered vault: $VAULT_PATH"
    else
        warn "Multiple vault candidates found:"
        i=1
        for v in "${VAULT_CANDIDATES[@]}"; do
            echo "    $i) $v"
            i=$((i + 1))
        done
        if [ "$ASSUME_YES" -eq 1 ]; then
            VAULT_PATH="${VAULT_CANDIDATES[0]}"
            info "--yes set — defaulting to the first candidate: $VAULT_PATH"
        elif [ "$DRY_RUN" -eq 1 ]; then
            VAULT_PATH="${VAULT_CANDIDATES[0]}"
            info "dry-run — defaulting to the first candidate: $VAULT_PATH"
        elif [ ! -t 0 ]; then
            fail "Multiple vault candidates and stdin is not a TTY. Pass --vault PATH (or --yes to accept the first match)."
        else
            printf "  Pick one [1-%d] (default 1): " "${#VAULT_CANDIDATES[@]}"
            read -r PICK
            PICK="${PICK:-1}"
            if ! [[ "$PICK" =~ ^[0-9]+$ ]] || [ "$PICK" -lt 1 ] || [ "$PICK" -gt "${#VAULT_CANDIDATES[@]}" ]; then
                fail "Invalid selection: $PICK"
            fi
            VAULT_PATH="${VAULT_CANDIDATES[$((PICK - 1))]}"
        fi
    fi
fi

if [ -z "$VAULT_PATH" ] || ! is_mogged_vault "$VAULT_PATH"; then
    fail "Vault path '$VAULT_PATH' is not a mogged vault (missing 02-Sources/, 01-Projects/, or CLAUDE.md)."
fi

success "Vault: $VAULT_PATH  (source: $VAULT_SOURCE)"

# -----------------------------------------------------------------------------
# 2. Resolve the export zip
#    Priority: --export-zip flag > EXPORT_ZIP env > CLAUDE_ZIP env > auto
# -----------------------------------------------------------------------------
echo ""
info "Looking for a Claude / ChatGPT data export..."

find_export_zip() {
    if [ -n "$EXPORT_ZIP_ARG" ]; then
        if [ -f "$EXPORT_ZIP_ARG" ]; then
            echo "$EXPORT_ZIP_ARG"
            return 0
        fi
        return 2
    fi
    if [ -n "${EXPORT_ZIP:-}" ] && [ -f "$EXPORT_ZIP" ]; then
        echo "$EXPORT_ZIP"
        return 0
    fi
    if [ -n "${CLAUDE_ZIP:-}" ] && [ -f "$CLAUDE_ZIP" ]; then
        echo "$CLAUDE_ZIP"
        return 0
    fi

    local search_dirs="$HOME/Downloads $HOME/Desktop $HOME/Documents"
    local dir found
    for dir in $search_dirs; do
        [ -d "$dir" ] || continue
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

ZIP_PATH=""
if ZIP_PATH=$(find_export_zip); then
    :
else
    RC=$?
    ZIP_PATH=""
    if [ "$RC" -eq 2 ]; then
        fail "--export-zip path does not exist: $EXPORT_ZIP_ARG"
    fi
fi

if [ -z "$ZIP_PATH" ]; then
    echo ""
    warn "No export zip found."
    echo ""
    echo -e "  ${YELLOW}Option 1 — Point the script at a specific zip${NC}"
    echo "    bash scripts/import-claude.sh --export-zip /path/to/your/export.zip"
    echo "    (or: export EXPORT_ZIP=/path/to/your/export.zip)"
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
# 3. Confirm + extract
# -----------------------------------------------------------------------------
STAGING="$VAULT_PATH/.import-staging/$(date +%Y%m%d-%H%M%S)-claude"

echo ""
info "Planned action:"
echo "    unzip  $ZIP_PATH"
echo "    into   $STAGING"
echo ""

if [ "$DRY_RUN" -eq 1 ]; then
    success "Dry-run complete — no files were written."
    echo ""
    echo "  Rerun without --dry-run (or with --yes for non-interactive) to stage the export."
    exit 0
fi

if [ "$ASSUME_YES" -ne 1 ]; then
    if [ ! -t 0 ]; then
        fail "stdin is not a TTY — pass --dry-run to preview, or --yes to auto-confirm."
    fi
    printf "  Proceed with extraction? [y/N] "
    read -r ANSWER
    case "${ANSWER:-}" in
        y|Y|yes|YES) ;;
        *) fail "Aborted by user." ;;
    esac
fi

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
echo "    - Route each into 01-Projects/<PROJECT>/conversations/<sub>/ as full-fidelity captures"
echo "    - Mirror each as a factual LIT-* note in 02-Sources/"
echo "    - Spawn linked concept stubs in 03-Concepts/ where ideas repeat"
echo "    - Update 04-Index/ + 01-Projects/<project>/ backlinks"
echo ""
echo "  If you prefer manual control, /backfill handles the same payload as a"
echo "  /save loop — slower but shows every write."
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
