#!/usr/bin/env bash
set -euo pipefail

sudo -v
sudo git config --global --add safe.directory "$(pwd)"

read -p "Enter hostname (DIY-Desktop/T480/patrick-desktop) or Enter for $(hostname -s): " input
HOSTNAME="${input:-$(hostname -s)}"

echo "Rebuilding system..."
sudo nixos-rebuild switch --flake ".#$HOSTNAME"

echo "Cleaning old generations (keeping last 3)..."
sudo nix-env --profile /nix/var/nix/profiles/system --delete-generations +3
sudo nix-collect-garbage

echo "Rebuild complete. Kernel: $(uname -r)"
