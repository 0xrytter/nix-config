#!/usr/bin/env bash
set -euo pipefail

HOSTNAME="${1:-$(hostname -s)}"
HARDWARE_SRC="/etc/nixos/hardware-configuration.nix"
HARDWARE_DST="$(dirname "$0")/hosts/$HOSTNAME/hardware-configuration.nix"

if [[ ! -f "$HARDWARE_SRC" ]]; then
    echo "ERROR: $HARDWARE_SRC not found. Run nixos-generate-config first."
    exit 1
fi

if [[ ! -d "$(dirname "$HARDWARE_DST")" ]]; then
    echo "ERROR: No host config found for '$HOSTNAME'. Available hosts:"
    ls "$(dirname "$0")/hosts/"
    exit 1
fi

cp "$HARDWARE_SRC" "$HARDWARE_DST"
echo "Copied hardware config for $HOSTNAME."
echo "Run ./update.sh to rebuild."
