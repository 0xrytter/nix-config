#!/usr/bin/env bash
set -euo pipefail

# Rebuild just the home-manager profile (no NixOS system rebuild).
# Usage:
#   bash home.sh                 # auto-detect profile (wsl2 inside WSL, else hostname)
#   bash home.sh <profile>       # e.g. wsl2, T480, DIY-Desktop, patrick-desktop
#   bash home.sh --list          # show available profiles

ROOT="$(cd "$(dirname "$0")" && pwd)"
HOST="$(hostname -s)"
AVAILABLE="wsl2 DIY-Desktop T480 patrick-desktop"

if [ "${1:-}" = "--list" ]; then
  echo "Available home-manager profiles: $AVAILABLE"
  exit 0
fi

if [ $# -ge 1 ]; then
  PROFILE="$1"
elif grep -qi microsoft /proc/version 2>/dev/null; then
  PROFILE="wsl2"
elif echo "$AVAILABLE" | grep -qw "$HOST"; then
  PROFILE="$HOST"
else
  echo "Could not detect profile (hostname '$HOST'). Available: $AVAILABLE" >&2
  echo "Usage: bash home.sh <profile>" >&2
  exit 1
fi

echo "Rebuilding home-manager profile '$PROFILE'..."
home-manager switch --flake "$ROOT/flake#$PROFILE"

echo "Done."