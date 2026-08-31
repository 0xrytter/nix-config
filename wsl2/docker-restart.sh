#!/usr/bin/env bash
set -euo pipefail

# Restart the Docker daemon inside WSL2, regardless of how it was started.

if [ "$(id -u)" -eq 0 ]; then
  echo "ERROR: run this script as a normal user (sudo is used internally)." >&2
  exit 1
fi

if [ "$(ps -p 1 -o comm= 2>/dev/null)" = "systemd" ]; then
  echo "Restarting Docker daemon via systemd..."
  sudo systemctl restart docker
else
  echo "systemd inactive; restarting dockerd manually..."
  sudo pkill -x dockerd || true
  sleep 1
  sudo nohup /usr/bin/dockerd > /tmp/dockerd.log 2>&1 &
fi

for _ in $(seq 1 15); do
  if docker info >/dev/null 2>&1; then
    echo "Docker daemon restarted successfully."
    exit 0
  fi
  sleep 1
done

echo "ERROR: Docker daemon did not come back up. Check 'journalctl -u docker' or /tmp/dockerd.log." >&2
exit 1