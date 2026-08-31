#!/usr/bin/env bash
set -euo pipefail

# Activate the wsl2 home-manager profile (standalone, no NixOS involved).

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
git config --global --add safe.directory "$ROOT"

echo "Activating home-manager profile 'wsl2'..."
home-manager switch --flake "$ROOT/flake#wsl2"

echo "Done. To run docker as a daemon:   bash wsl2/docker-setup.sh"