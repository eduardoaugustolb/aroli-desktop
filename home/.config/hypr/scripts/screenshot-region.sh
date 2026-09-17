#!/usr/bin/env bash
# Region screenshot: freezes the screen, crops, saves, and copies.
# Freezing (capture-region.sh) makes it possible to capture menus, the notch,
# or anything that closes when it loses focus.
set -uo pipefail

dir="$HOME/Pictures/screenshots"
mkdir -p "$dir"
file="$dir/screenshot-$(date +%Y%m%d_%H%M%S).png"

if "$HOME/.config/hypr/scripts/capture-region.sh" > "$file" && [ -s "$file" ]; then
    wl-copy < "$file"
    # In the background: the notification waits in case you click "Edit".
    "$HOME/.config/hypr/scripts/notify-shot.sh" "$file" &
else
    rm -f "$file"   # Canceled: do not leave a zero-byte PNG in Pictures.
fi
