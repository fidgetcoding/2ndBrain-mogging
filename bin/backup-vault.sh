#!/usr/bin/env bash
#
# 2ndBrain-mogging — backup-vault.sh
#
# Usage:
#   backup-vault.sh [VAULT_PATH]
#
# Produces ~/WORK/<vault-name>-BACKUPS/<vault-name>-backup-YYYYMMDD-HHMMSS.tar.gz
# from the given vault path. Vault resolution order: $1 arg, then the
# ~/.claude/.mogging-vault marker install.sh writes, then ~/BRAIN2.
# Excludes Obsidian workspace state files and .DS_Store.
#
# NEVER writes to ~/Desktop — modern macOS permission-protects it (TCC),
# and the vault non-negotiables forbid Desktop tarballs outright.
#

set -euo pipefail
IFS=$'\n\t'

VAULT="${1:-}"
if [[ -z "$VAULT" && -f "$HOME/.claude/.mogging-vault" ]]; then
  VAULT="$(head -n 1 "$HOME/.claude/.mogging-vault" | tr -d '\r\n')"
fi
VAULT="${VAULT:-$HOME/BRAIN2}"

if [[ ! -d "$VAULT" ]]; then
  echo "backup-vault: not a directory: $VAULT" >&2
  exit 1
fi

VAULT_ABS="$(cd -P "$VAULT" >/dev/null 2>&1 && pwd)"
PARENT="$(dirname "$VAULT_ABS")"
NAME="$(basename "$VAULT_ABS")"
BACKUP_DIR="$HOME/WORK/${NAME}-BACKUPS"
mkdir -p "$BACKUP_DIR"
OUT="$BACKUP_DIR/${NAME}-backup-$(date +%Y%m%d-%H%M%S).tar.gz"

tar --exclude='.obsidian/workspace*' \
    --exclude='.DS_Store' \
    -czf "$OUT" \
    -C "$PARENT" "$NAME"

echo "$OUT"
