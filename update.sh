#!/usr/bin/env bash
set -euo pipefail

sudo -v
sudo git config --global --add safe.directory "$(pwd)"

read -p "Enter hostname (DIY-Desktop/T480/patrick-desktop) or Enter for $(hostname -s): " input
HOSTNAME="${input:-$(hostname -s)}"

echo "Updating flake..."
nix flake update --flake "./flake"

echo "Rebuilding with updated flake..."
sudo nixos-rebuild switch --flake "./flake#$HOSTNAME"

echo "Cleaning old generations (keeping last 3)..."
sudo nix-env --profile /nix/var/nix/profiles/system --delete-generations +3
sudo nix-collect-garbage

echo "Optimizing store..."
sudo nix-store --optimise

echo "Wiping old profiles..."
nix profile wipe-history --keep-minimum 3 2>/dev/null || true
sudo nix profile wipe-history --keep-minimum 3 2>/dev/null || true

echo "Cleaning caches..."
rm -rf ~/.cache/nix*

echo "Update complete. Kernel: $(uname -r)"
