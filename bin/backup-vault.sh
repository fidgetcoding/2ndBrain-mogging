#!/usr/bin/env bash
#
# 2ndBrain-mogging — backup-vault.sh
#
# Usage:
#   backup-vault.sh [VAULT_PATH]
#
# Produces ~/Desktop/2ndBrain-backup-YYYYMMDD-HHMMSS.tar.gz from the given
# vault path (defaults to ~/Desktop/WORK/OBSIDIAN/2ndBrain). Excludes
# Obsidian workspace state files and .DS_Store.
#

set -euo pipefail
IFS=$'\n\t'

VAULT="${1:-$HOME/Desktop/WORK/OBSIDIAN/2ndBrain}"

if [[ ! -d "$VAULT" ]]; then
  echo "backup-vault: not a directory: $VAULT" >&2
  exit 1
fi

VAULT_ABS="$(cd -P "$VAULT" >/dev/null 2>&1 && pwd)"
PARENT="$(dirname "$VAULT_ABS")"
NAME="$(basename "$VAULT_ABS")"
OUT="$HOME/Desktop/2ndBrain-backup-$(date +%Y%m%d-%H%M%S).tar.gz"

tar --exclude='.obsidian/workspace*' \
    --exclude='.DS_Store' \
    -czf "$OUT" \
    -C "$PARENT" "$NAME"

echo "$OUT"
