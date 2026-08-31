#!/usr/bin/env bash
set -euo pipefail

# Activate the wsl2 home-manager profile (standalone, no NixOS involved).

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
git config --global --add safe.directory "$ROOT"

echo "Activating home-manager profile 'wsl2'..."
home-manager switch --flake "$ROOT/flake#wsl2"

# Ensure fish is the login shell so WSL and tmux both start fish.
# Requires sudo the first time (writes /etc/shells + updates /etc/passwd).
FISH_PATH="$(command -v fish || true)"
if [ -n "$FISH_PATH" ]; then
  if ! grep -Fxq "$FISH_PATH" /etc/shells 2>/dev/null; then
    echo "==> Adding $FISH_PATH to /etc/shells (sudo)"
    echo "$FISH_PATH" | sudo tee -a /etc/shells >/dev/null
  fi
  if [ "$(getent passwd "$USER" | cut -d: -f7)" != "$FISH_PATH" ]; then
    echo "==> Setting fish as the login shell for $USER (sudo)"
    sudo chsh -s "$FISH_PATH" "$USER"
    echo "  Done. Next distro launch will use fish."
  fi
else
  echo "WARNING: fish not found on PATH; skipping login-shell setup."
fi

echo "Done. To run docker as a daemon:   bash wsl2/docker-setup.sh"
