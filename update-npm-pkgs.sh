#!/usr/bin/env bash
set -euo pipefail

# Updates npm-based nix derivations in flake/pkgs/
# Usage: ./update-npm-pkgs.sh

PKGS_DIR="$(dirname "$0")/flake/pkgs"

update_pkg() {
    local file="$1"
    local npm_name="$2"

    echo "Checking $npm_name..."
    local latest
    latest=$(curl -s "https://registry.npmjs.org/$npm_name/latest" | python3 -c "import sys,json; print(json.load(sys.stdin)['version'])")
    local current
    current=$(grep 'version = ' "$file" | head -1 | grep -oP '".*?"' | tr -d '"')

    if [[ "$latest" == "$current" ]]; then
        echo "  $npm_name is up to date ($current)"
        return
    fi

    echo "  Updating $npm_name: $current → $latest"

    local tarball_url="https://registry.npmjs.org/$npm_name/-/$(basename "$npm_name")-${latest}.tgz"
    local new_hash
    new_hash=$(nix-prefetch-url --type sha256 "$tarball_url" 2>/dev/null | xargs -I{} nix hash convert --type sha256 --to sri {})

    sed -i "s/version = \"$current\"/version = \"$latest\"/" "$file"
    sed -i "s|hash = \"sha256-.*\"|hash = \"${new_hash}\"|" "$file"
    # Reset npmDepsHash so rebuild will report the correct one
    sed -i 's/npmDepsHash = ".*"/npmDepsHash = lib.fakeHash/' "$file"

    echo "  Updated. Run ./rebuild.sh — it will fail once with the correct npmDepsHash, paste it in, then rebuild again."
}

update_pkg "$PKGS_DIR/pi-coding-agent.nix" "@mariozechner/pi-coding-agent"

echo ""
echo "Done."
