#!/usr/bin/env bash
set -euo pipefail

sudo -v
sudo git config --global --add safe.directory "$(pwd)"

if grep -qi microsoft /proc/version 2>/dev/null; then
  PROFILE="wsl2"
else
  read -p "Enter hostname (DIY-Desktop/T480/patrick-desktop) or Enter for $(hostname -s): " input
  PROFILE="${input:-$(hostname -s)}"
fi

echo "Updating flake..."
nix flake update --flake "./flake"

echo "Rebuilding with updated flake..."
if [ "$PROFILE" = "wsl2" ]; then
  home-manager switch --flake "./flake#wsl2"
else
  sudo nixos-rebuild switch --flake "./flake#$PROFILE"
fi

if [ "$PROFILE" != "wsl2" ]; then
  echo "Cleaning old generations (keeping last 3)..."
  sudo nix-env --profile /nix/var/nix/profiles/system --delete-generations +3
  sudo nix-collect-garbage
fi

echo "Optimizing store..."
sudo nix-store --optimise

echo "Wiping old profiles..."
nix profile wipe-history --keep-minimum 3 2>/dev/null || true
sudo nix profile wipe-history --keep-minimum 3 2>/dev/null || true

echo "Cleaning caches..."
rm -rf ~/.cache/nix*

echo "Update complete. Kernel: $(uname -r)"
