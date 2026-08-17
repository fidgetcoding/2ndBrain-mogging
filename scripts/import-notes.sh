#!/usr/bin/env bash
set -uo pipefail

# ============================================================================
# import-notes.sh
# Pre-flight helper for importing existing notes (Apple Notes, OneNote,
# Notion, Evernote, raw files) into your 2ndBrain-mogging vault.
#
# This script is INTENTIONALLY READ-ONLY today. It:
#   - Resolves the mogged vault
#   - Checks for Exporter.app (Apple Notes → markdown)
#   - Checks for pandoc / xlsx2csv
#   - Scans common locations for candidate files
#   - Prints a handoff block for the /import-notes skill
#
# The actual file movement / categorization is performed by the /import-notes
# Claude skill, NOT by this script. The --dry-run / --yes flags exist so the
# same flag surface carries through when the skill (or future write-mode)
# invokes this script.
#
# Flags (see --help for the full list):
#   --vault PATH        Use this vault instead of auto-discovery.
#   --source DIR        Directory holding exported notes (required).
#   --kind KIND         Optional source hint: apple|onenote|notion|evernote|raw.
#   --dry-run           Scan + report only (today this is the default — noted
#                       so future write modes inherit the flag).
#   --yes, -y           Auto-confirm any prompts.
#   --help, -h          Print usage and exit.
#
# Exit codes:
#   0 — success
#   1 — user-facing runtime error (no vault, missing --source, …)
#   2 — usage error (unknown flag, missing flag value, bad --kind)
# ============================================================================

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
import-notes.sh — pre-flight helper for the /import-notes skill

This script is READ-ONLY today. It inspects your environment, locates the
vault, counts candidate export files, and prints a handoff block pointing at
the /import-notes Claude skill (which performs the actual conversion and
routing). The flags below exist so the same interface works when the skill
or a future write-mode invokes this script.

USAGE:
    bash scripts/import-notes.sh [OPTIONS]
    bash <(curl -fsSL https://…/import-notes.sh) [OPTIONS]

OPTIONS:
    --vault PATH           Path to your mogged vault. Overrides auto-discovery.
                           (Also honored via VAULT_PATH env var.)
    --source DIR           Directory holding your exported notes.
                           Required — even in dry-run the scan needs a root.
                           Common: ~/Desktop/apple-notes-export, ~/Downloads/notion-export.
    --kind KIND            Optional hint for what's in --source.
                           One of: apple, onenote, notion, evernote, raw.
                           (Default: auto-detect from filenames.)
    --dry-run              Scan + report only, no staging-dir creation.
                           This script is already no-write today, so this flag
                           is a guarantee — future write modes will honor it.
    --yes, -y              Auto-confirm any prompts (non-interactive).
    -h, --help             Print this help and exit.

FLOW:
    1. Resolve the vault (--vault > VAULT_PATH > auto-discovery).
    2. Check environment: Exporter.app (macOS), pandoc, xlsx2csv.
    3. If --source was given, count candidate files in it (by extension).
       Otherwise, scan ~/Desktop, ~/Downloads, ~/Documents for candidates.
    4. Print a handoff block pointing at /import-notes.

NOTES ON BEHAVIOR:
    - Nothing is moved, copied, or deleted by this script today.
    - The /import-notes skill does the actual categorization into 02-Sources/,
      03-Concepts/, 01-Projects/, etc., and asks before writing.
    - --source is recommended but not strictly required for the legacy
      multi-location scan. Passing --kind without --source is a usage error.

EXIT CODES:
    0   success
    1   runtime error (no vault, etc.)
    2   usage error  (unknown flag, bad --kind value, missing flag value)

EXAMPLES:
    # Full pre-flight on an Apple Notes export:
    bash scripts/import-notes.sh \
        --vault ~/MyVault \
        --source ~/Desktop/apple-notes-export \
        --kind apple --dry-run

    # Legacy "just scan common locations" mode:
    bash scripts/import-notes.sh --yes
USAGE
}

# -----------------------------------------------------------------------------
# Argument parser
# -----------------------------------------------------------------------------
DRY_RUN=0
ASSUME_YES=0
VAULT_PATH="${VAULT_PATH:-}"
SOURCE_DIR=""
KIND=""

validate_kind() {
    case "$1" in
        apple|onenote|notion|evernote|raw) return 0 ;;
        *) return 1 ;;
    esac
}

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
        --source)
            if [ $# -lt 2 ] || [ -z "${2:-}" ]; then
                echo "error: --source requires a DIR argument" >&2
                exit 2
            fi
            SOURCE_DIR="$2"
            shift 2
            ;;
        --source=*)
            SOURCE_DIR="${1#--source=}"
            shift
            ;;
        --kind)
            if [ $# -lt 2 ] || [ -z "${2:-}" ]; then
                echo "error: --kind requires one of: apple|onenote|notion|evernote|raw" >&2
                exit 2
            fi
            if ! validate_kind "$2"; then
                echo "error: invalid --kind: '$2' (expected apple|onenote|notion|evernote|raw)" >&2
                exit 2
            fi
            KIND="$2"
            shift 2
            ;;
        --kind=*)
            KIND_VAL="${1#--kind=}"
            if ! validate_kind "$KIND_VAL"; then
                echo "error: invalid --kind: '$KIND_VAL' (expected apple|onenote|notion|evernote|raw)" >&2
                exit 2
            fi
            KIND="$KIND_VAL"
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
            echo "run 'bash scripts/import-notes.sh --help' for usage" >&2
            exit 2
            ;;
        *)
            echo "error: unexpected positional arg: $1" >&2
            echo "run 'bash scripts/import-notes.sh --help' for usage" >&2
            exit 2
            ;;
    esac
done

if [ -n "$KIND" ] && [ -z "$SOURCE_DIR" ]; then
    echo "error: --kind requires --source to also be set" >&2
    exit 2
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  import-notes — Pre-Flight for /import-notes${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
if [ "$DRY_RUN" -eq 1 ]; then
    echo -e "${YELLOW}  (dry-run — scan + report only, no writes)${NC}"
else
    echo -e "${YELLOW}  (note: this script is currently read-only regardless of flags)${NC}"
fi
echo ""

# -----------------------------------------------------------------------------
# 1. Resolve the vault
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
    # (~/MyVault; Desktop/Documents are TCC-protected on modern macOS).
    for candidate in \
        "$HOME/MyVault" \
        "$HOME/BRAIN" \
        "$HOME/2ndBrain" \
        "$HOME/Second-Brain" \
        "$HOME/Desktop/BRAIN" \
        "$HOME/Desktop/MyVault" \
        "$HOME/Desktop/2ndBrain" \
        "$HOME/Desktop/Second-Brain" \
        "$HOME/Documents/BRAIN" \
        "$HOME/Documents/2ndBrain"; do
        if is_mogged_vault "$candidate"; then
            VAULT_CANDIDATES+=("$candidate")
        fi
    done

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
if command -v pandoc >/dev/null 2>&1; then
    success "pandoc available  — handles .docx / .pptx / .html / .rtf / .epub → markdown"
else
    warn "pandoc not found — install via 'brew install pandoc' if you have Word/PowerPoint exports"
fi

if python3 -c "import xlsx2csv" >/dev/null 2>&1; then
    success "xlsx2csv available — handles Excel spreadsheets"
else
    warn "xlsx2csv not found — install via 'pip3 install xlsx2csv' if you have .xlsx exports"
fi

# -----------------------------------------------------------------------------
# 4. Scan for candidate files
#    If --source was given, scan that only. Otherwise fall back to the
#    legacy multi-location scan.
# -----------------------------------------------------------------------------
echo ""
NOTES_FOUND=0
SUMMARY=""

scan_dir() {
    local target="$1"
    [ -d "$target" ] || return 0
    local count
    count=$(find "$target" -maxdepth 3 \( \
        -name "*.md" -o -name "*.txt" -o -name "*.docx" -o -name "*.pptx" \
        -o -name "*.xlsx" -o -name "*.html" -o -name "*.htm" -o -name "*.rtf" \
        -o -name "*.enex" -o -name "*.json" \
    \) 2>/dev/null | wc -l | tr -d ' ')
    if [ "$count" -gt 0 ]; then
        info "Found $count candidate file(s) in $target"
        NOTES_FOUND=$((NOTES_FOUND + count))
        SUMMARY="$SUMMARY\n    - $target: $count"
    fi
}

if [ -n "$SOURCE_DIR" ]; then
    if [ ! -d "$SOURCE_DIR" ]; then
        fail "--source path does not exist or is not a directory: $SOURCE_DIR"
    fi
    info "Scanning --source: $SOURCE_DIR"
    if [ -n "$KIND" ]; then
        info "Kind hint: $KIND"
    fi
    scan_dir "$SOURCE_DIR"
else
    info "No --source given — scanning common locations for exported notes..."
    for d in "$HOME/Desktop" "$HOME/Downloads" "$HOME/Documents"; do
        scan_dir "$d"
    done
fi

# -----------------------------------------------------------------------------
# 5. Hand off to Claude
# -----------------------------------------------------------------------------
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  Environment ready — hand off to Claude${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  Vault:            $VAULT_PATH"
if [ -n "$SOURCE_DIR" ]; then
    echo "  Source:           $SOURCE_DIR"
fi
if [ -n "$KIND" ]; then
    echo "  Kind hint:        $KIND"
fi
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
echo "    - Tether project-tied material into 01-Projects/<project>/"
echo "    - Ask you before touching anything (dry-run preview first)"
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
