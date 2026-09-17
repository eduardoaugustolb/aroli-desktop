#!/usr/bin/env bash
# Read-only release gate for Umbra Noctis. It never installs packages, starts
# services, or needs a graphical session.
set -euo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

gocache="$(mktemp -d)"
trap 'rm -rf "$gocache"' EXIT
GOCACHE="$gocache" go test ./...
bash -n home/.local/bin/game-mode home/.local/bin/battery-efficiency \
    home/.config/hypr/scripts/reading-mode.sh
python3 home/.config/quickshell/tools/i18n-check.py
git diff --check
printf 'Umbra Noctis smoke test passed.\n'
