#!/usr/bin/env bash
set -euo pipefail

# Put this workstation on the tailnet, so the fleet's applications - obs01's
# Grafana, agent01's Crush API - answer here directly instead of through an SSH
# forward.
#
#   bash wsl2/tailscale-setup.sh                     # fleet addresses only
#   bash wsl2/tailscale-setup.sh --accept-dns        # and the fleet's host names
#
# Two halves, one password prompt. The system half needs root because a tun
# interface does and home-manager owns no system services on Ubuntu; the join
# needs root too, and sudo resets PATH to a root-safe default, which is why every
# call below uses the client's full path rather than a bare `tailscale`. It ends
# by handing the node to $USER, so nothing afterwards needs sudo at all.
#
# Idempotent: safe to re-run.

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
UNIT="$ROOT/wsl2/tailscaled.service"
CLI="$HOME/.nix-profile/bin/tailscale"
ACCEPT_DNS=""

for arg in "$@"; do
  case "$arg" in
  --accept-dns) ACCEPT_DNS="--accept-dns=true" ;;
  *)
    echo "ERROR: unknown argument: $arg" >&2
    exit 1
    ;;
  esac
done

if [ "$(id -u)" -eq 0 ]; then
  echo "ERROR: run this script as a normal user (sudo is used internally)." >&2
  exit 1
fi

if [ "$(ps -p 1 -o comm= 2>/dev/null)" != "systemd" ]; then
  echo "ERROR: systemd is not PID 1. Enable it in /etc/wsl.conf, run 'wsl --shutdown'" >&2
  echo "       from Windows, and start this distro again." >&2
  exit 1
fi

if [ ! -x "$CLI" ]; then
  echo "ERROR: $CLI is missing. Rebuild the profile first:" >&2
  echo "       bash wsl2/switch.sh" >&2
  exit 1
fi

if [ ! -e /dev/net/tun ]; then
  echo "ERROR: /dev/net/tun is missing, so tailscaled cannot create its interface." >&2
  exit 1
fi

echo "==> Linking the unit into systemd"
if ! sudo systemctl link "$UNIT"; then
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

echo "==> Joining the tailnet"
echo "    An unauthenticated machine prints a URL here - open it in Windows and"
echo "    this waits for you."
sudo "$CLI" up ${ACCEPT_DNS}

# After the join, so a machine that fails to authorise does not leave the CLI
# looking like it works. This is what makes `tailscale status` run as $USER.
echo "==> Handing the node to $USER, so the CLI needs no sudo from here on"
sudo "$CLI" set --operator="$USER"

echo ""
echo "On the tailnet. What it can see:"
"$CLI" status | sed -n '1,8p'
echo ""
echo "Check the fleet with:"
echo "    curl -s http://100.118.112.28:3000/api/health    # obs01, Grafana"
echo "    crush -H tcp://100.76.233.93:7799                # agent01"
echo ""
echo "With --accept-dns those names resolve too; without it use the addresses, or"
echo "run 'status.sh' in the iacthing repository for the current ones."
