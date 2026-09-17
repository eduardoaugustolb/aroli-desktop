#!/usr/bin/env bash
# Captures a region and opens it in satty for annotation; saves and copies it.
# It uses a frozen screen (capture-region.sh), so you can also annotate an open
# menu or the notch.
set -uo pipefail

dir="$HOME/Pictures/screenshots"
mkdir -p "$dir"
tmp=$(mktemp --suffix=.png)
trap 'rm -f "$tmp"' EXIT

"$HOME/.config/hypr/scripts/capture-region.sh" > "$tmp" || exit 0
[ -s "$tmp" ] || exit 0

satty --filename "$tmp" \
      --output-filename "$dir/satty-$(date +%Y%m%d_%H%M%S).png" \
      --copy-command wl-copy --early-exit
