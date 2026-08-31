#!/usr/bin/env bash
set -euo pipefail

# First-time setup on a fresh Ubuntu WSL2 distro.
# Installs Nix + home-manager, activates this flake's wsl2 profile,
# makes fish the default shell, and drops you into a fish shell.

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
bash wsl2/switch.sh

echo "==> Setting fish as the default shell =="
# fish lives in the home-manager profile; make sure nix is on PATH.
# shellcheck source=/dev/null
. "$HOME/.nix-profile/etc/profile.d/nix.sh" 2>/dev/null || true
FISH_BIN="$(command -v fish || echo "$HOME/.nix-profile/bin/fish")"

if ! grep -qx "$FISH_BIN" /etc/shells 2>/dev/null; then
  echo "$FISH_BIN" | sudo tee -a /etc/shells >/dev/null
  echo "  -> added $FISH_BIN to /etc/shells"
fi

if [ "$(getent passwd "$USER" | cut -d: -f7)" != "$FISH_BIN" ]; then
  sudo chsh -s "$FISH_BIN" "$USER"
  echo "  -> default shell set to $FISH_BIN"
else
  echo "  -> fish is already your default shell"
fi

echo "==> Entering fish shell =="
exec "$FISH_BIN" -l