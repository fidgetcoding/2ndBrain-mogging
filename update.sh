#!/usr/bin/env bash
# Refresh a complete, persistent checkout: installed links must outlive this run.
set -euo pipefail
CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
VAULT=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --vault) [ "$#" -ge 2 ] && [ -n "$2" ] || { echo '--vault requires a path' >&2; exit 2; }; VAULT="$2"; shift 2 ;;
    --vault=*) VAULT="${1#*=}"; shift ;;
    -h|--help) echo 'Usage: update.sh [--vault PATH]'; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done
if [ -z "$VAULT" ] && [ -f "$CLAUDE_HOME/.mogging-vault" ]; then
  VAULT="$(head -n1 "$CLAUDE_HOME/.mogging-vault" | tr -d '\r\n')"
fi
[ -n "$VAULT" ] && [ -d "$VAULT" ] || { echo 'Pass --vault with an existing vault directory.' >&2; exit 1; }
case "/$VAULT/" in */../*) echo 'Vault path must not contain ..' >&2; exit 2 ;; esac

# Prefer the installed checkout so existing symlinks keep resolving after updates.
CHECKOUT="$CLAUDE_HOME/2ndbrain-mogging"
if [ -L "$CLAUDE_HOME/skills/save" ]; then
  CHECKOUT="$(cd -P "$CLAUDE_HOME/skills/save/../.." && pwd)"
fi
if [ -d "$CHECKOUT/.git" ] || [ -f "$CHECKOUT/.git" ]; then
  origin="$(git -C "$CHECKOUT" remote get-url origin)"
  case "$origin" in
    https://github.com/fidgetcoding/2ndBrain-mogging|https://github.com/fidgetcoding/2ndBrain-mogging.git|git@github.com:fidgetcoding/2ndBrain-mogging.git) ;;
    *) echo 'Installed checkout has a different origin; update it manually.' >&2; exit 1 ;;
  esac
  [ -z "$(git -C "$CHECKOUT" status --porcelain)" ] || { echo 'Checkout has local changes; preserve them before updating.' >&2; exit 1; }
  [ "$(git -C "$CHECKOUT" branch --show-current)" = main ] || { echo 'Checkout is not on main; update it manually.' >&2; exit 1; }
  git -C "$CHECKOUT" pull --ff-only origin main
else
  [ ! -e "$CHECKOUT" ] && [ ! -L "$CHECKOUT" ] || { echo 'Checkout path is occupied; leaving it unchanged.' >&2; exit 1; }
  mkdir -p "$CLAUDE_HOME"
  git clone --depth 1 --branch main https://github.com/fidgetcoding/2ndBrain-mogging.git "$CHECKOUT"
fi
[ -f "$CHECKOUT/install.sh" ] && [ -d "$CHECKOUT/skills" ] || { echo 'Incomplete checkout; update stopped.' >&2; exit 1; }
bash "$CHECKOUT/install.sh" --apply --vault "$VAULT"
echo 'Update complete.'
