#!/usr/bin/env bash
set -euo pipefail

# Put this workstation on the tailnet, so the fleet's applications - obs01's
# Grafana, agent01's Crush API - answer here directly instead of through an SSH
# forward. Idempotent: safe to re-run.
#
# The binary comes from the home-manager profile (flake/modules/home/wsl2.nix),
# not from a package manager. What is left for this script is the part
# home-manager cannot own on Ubuntu: a system service, because creating a tun
# interface needs root.

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
UNIT="$ROOT/wsl2/tailscaled.service"
DAEMON="$HOME/.nix-profile/bin/tailscaled"
CLI="$HOME/.nix-profile/bin/tailscale"

if [ "$(id -u)" -eq 0 ]; then
  echo "ERROR: run this script as a normal user (sudo is used internally)." >&2
  exit 1
fi

if [ "$(ps -p 1 -o comm= 2>/dev/null)" != "systemd" ]; then
  echo "ERROR: systemd is not PID 1. Enable it in /etc/wsl.conf, run 'wsl --shutdown'" >&2
  echo "       from Windows, and start this distro again." >&2
  exit 1
fi

if [ ! -x "$DAEMON" ]; then
  echo "ERROR: $DAEMON is missing. Rebuild the profile first:" >&2
  echo "       bash wsl2/switch.sh" >&2
  exit 1
fi

if [ ! -e /dev/net/tun ]; then
  echo "ERROR: /dev/net/tun is missing, so tailscaled cannot create its interface." >&2
  exit 1
fi

echo "==> Linking the unit into systemd"
if ! sudo systemctl link "$UNIT" 2>/dev/null; then
  echo "  -> systemd refused the repository path; installing a copy instead"
  sudo install -m 0644 -o root -g root "$UNIT" /etc/systemd/system/tailscaled.service
  sudo systemctl daemon-reload
fi

echo "==> Starting tailscaled"
sudo systemctl enable --now tailscaled

echo "==> Waiting for the daemon socket"
for _ in $(seq 1 15); do
  [ -S /run/tailscale/tailscaled.sock ] && break
  sleep 1
done

if [ ! -S /run/tailscale/tailscaled.sock ]; then
  echo "ERROR: tailscaled did not come up. Check 'journalctl -u tailscaled'." >&2
  exit 1
fi

echo ""
echo "tailscaled is running. Two commands are left, the first of which needs your"
echo "authorisation and prints a URL to open in Windows:"
echo ""
echo "    sudo $CLI up"
echo "    sudo $CLI set --operator=$USER      # so the CLI needs no sudo after this"
echo ""
echo "The full path is not a typo. sudo resets PATH to a root-safe default, so a"
echo "client that lives in your home profile is invisible to it - 'sudo tailscale'"
echo "finds nothing. The operator flag is what makes a plain 'tailscale status'"
echo "work afterwards, without sudo and without the path."
echo ""
echo "Add --accept-dns=true to the up command if you want the fleet's host names to"
echo "resolve too; step 9 of wsl2/README.md says what else that needs."
echo ""
echo "Then verify with:"
echo "    tailscale status                   # the three boxes listed"
echo "    curl -s http://obs01:3000/api/health"
echo "    crush -H tcp://agent01:7799"
