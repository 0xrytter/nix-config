#!/usr/bin/env bash
set -euo pipefail

# Setup Docker Engine inside WSL2 (Ubuntu) and run it as a daemon by default.
# Idempotent: safe to re-run.

if [ "$(id -u)" -eq 0 ]; then
  echo "ERROR: run this script as a normal user (sudo is used internally)." >&2
  exit 1
fi

SYSTEMD_BOOT=$(ps -p 1 -o comm= 2>/dev/null)

echo "==> Enabling systemd for WSL2 (required for the Docker daemon service) =="
sudo bash -c 'grep -q "^\[boot\]" /etc/wsl.conf 2>/dev/null || printf "\n[boot]\n" >> /etc/wsl.conf'
sudo bash -c 'grep -q "^systemd=true" /etc/wsl.conf 2>/dev/null || printf "systemd=true\n" >> /etc/wsl.conf'
echo "  -> systemd enabled in /etc/wsl.conf"

if [ "$SYSTEMD_BOOT" != "systemd" ]; then
  echo "  WARNING: systemd is not PID 1 yet."
  echo "  Run 'wsl --shutdown' from Windows PowerShell, then start this distro again"
  echo "  before the Docker daemon can auto-start on boot."
fi

echo "==> Installing Docker Engine =="
if ! command -v docker >/dev/null 2>&1; then
  curl -fsSL https://get.docker.com | sudo sh
else
  echo "  -> docker already installed ($(docker --version))"
fi

echo "==> Adding '$USER' to the docker group =="
if id -nG | grep -qw docker; then
  echo "  -> already a member"
else
  sudo usermod -aG docker "$USER"
  echo "  -> added '$USER' to the docker group (re-login or restart the distro to apply)"
fi

echo "==> Starting docker as a daemon =="
if [ "$SYSTEMD_BOOT" = "systemd" ]; then
  sudo systemctl enable docker
  sudo systemctl start docker
else
  if ! pgrep -x dockerd >/dev/null 2>&1; then
    sudo nohup /usr/bin/dockerd > /tmp/dockerd.log 2>&1 &
    echo "  -> systemd inactive; started dockerd in the background (log: /tmp/dockerd.log)"
  else
    echo "  -> dockerd already running"
  fi
fi

for _ in $(seq 1 15); do
  if docker info >/dev/null 2>&1; then
    echo ""
    echo "Docker daemon is up and running."
    docker version | sed -n '1,6p'
    echo ""
    echo "Verify with: docker run --rm hello-world"
    exit 0
  fi
  sleep 1
done

echo "ERROR: Docker daemon did not become reachable. Check 'journalctl -u docker' or /tmp/dockerd.log." >&2
exit 1