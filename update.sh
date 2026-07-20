#!/usr/bin/env bash
# update.sh — 2ndBrain-mogging updater.
#
# Re-applies the latest mogging install by locating your vault from the
# ~/.claude/.mogging-vault marker written at first install, then running
# install.sh --apply against it. This is the one-liner the weekly notifier
# hands out, so it must work with zero arguments on a machine that has
# already installed once.
#
# Usage:
#   bash <(curl -fsSL https://raw.githubusercontent.com/fidgetcoding/2ndBrain-mogging/main/update.sh)
#   bash <(curl -fsSL .../update.sh) --vault /path/to/vault   # explicit override
set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/fidgetcoding/2ndBrain-mogging/main"
MARKER="$HOME/.claude/.mogging-vault"

VAULT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --vault) VAULT="${2:-}"; shift 2 ;;
    -h|--help) echo "Usage: update.sh [--vault PATH]"; exit 0 ;;
    *) shift ;;
  esac
done

if [ -z "$VAULT" ] && [ -f "$MARKER" ]; then
  VAULT="$(head -n1 "$MARKER" | tr -d '\n')"
fi

if [ -z "$VAULT" ]; then
  echo "✗ Could not locate your vault (no ~/.claude/.mogging-vault marker found)."
  echo "  Re-run with your vault path:"
  echo "    bash <(curl -fsSL $REPO_RAW/update.sh) --vault /absolute/path/to/vault"
  exit 1
fi

if [ ! -d "$VAULT" ]; then
  echo "✗ Vault path is not a directory: $VAULT"
  exit 1
fi

echo "🧠 Updating 2ndBrain-mogging → $VAULT"
bash <(curl -fsSL "$REPO_RAW/install.sh") --apply --vault "$VAULT"
echo "✓ Update complete."
