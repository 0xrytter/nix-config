#!/usr/bin/env bash
set -euo pipefail

# Cache sudo credentials upfront — one prompt for the whole script
sudo -v

read -p "Enter hostname (DIY-Desktop/T480/patrick-desktop) or Enter for $(hostname -s): " input
HOSTNAME="${input:-$(hostname -s)}"
FLAKE_PATH="."

echo "Rebuilding system..."
sudo nixos-rebuild switch --flake "$FLAKE_PATH#$HOSTNAME"

echo "Cleaning old generations (keeping last 3)..."
sudo nix-env --profile /nix/var/nix/profiles/system --delete-generations +3
sudo nix-collect-garbage

echo "Rebuild complete. Kernel: $(uname -r)"

read -p "Run flake update + full cleanup? [y/N] " do_update
if [[ "${do_update,,}" == "y" ]]; then
    echo "Updating flake..."
    nix flake update --flake "$FLAKE_PATH"

    echo "Rebuilding with updated flake..."
    sudo nixos-rebuild switch --flake "$FLAKE_PATH#$HOSTNAME"

    echo "Optimizing store..."
    sudo nix-store --optimise

    echo "Wiping old profiles..."
    nix profile wipe-history --keep-minimum 3 2>/dev/null || true
    sudo nix profile wipe-history --keep-minimum 3 2>/dev/null || true

    echo "Cleaning caches..."
    rm -rf ~/.cache/nix*

    echo "Update complete. Kernel: $(uname -r)"
fi
