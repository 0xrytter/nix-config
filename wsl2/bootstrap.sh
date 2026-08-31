#!/usr/bin/env bash
set -euo pipefail

# First-time setup on a fresh Ubuntu WSL2 distro.
# Installs Nix + home-manager, then activates this flake's wsl2 profile.

if [ "$(id -u)" -eq 0 ]; then
  echo "ERROR: run as a normal user." >&2
  exit 1
fi

if ! command -v nix >/dev/null 2>&1; then
  echo "==> Installing Nix (single-user, no daemon needed in WSL2) =="
  sh <(curl -L https://nixos.org/nix/install) --no-daemon
  # shellcheck source=/dev/null
  . "$HOME/.nix-profile/etc/profile.d/nix.sh"
else
  echo "  -> nix already installed ($(nix --version))"
  # shellcheck source=/dev/null
  . "$HOME/.nix-profile/etc/profile.d/nix.sh" 2>/dev/null || true
fi

mkdir -p "$HOME/.config/nix"
if ! grep -q '^experimental-features' "$HOME/.config/nix/nix.conf" 2>/dev/null; then
  echo 'experimental-features = nix-command flakes' >> "$HOME/.config/nix/nix.conf"
fi

if ! command -v home-manager >/dev/null 2>&1; then
  echo "==> Installing home-manager =="
  nix profile install "github:nix-community/home-manager"
else
  echo "  -> home-manager already installed"
fi

cd "$(dirname "$0")/.."
exec bash wsl2/switch.sh