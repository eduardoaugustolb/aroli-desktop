#!/usr/bin/env bash
# Full, instant screenshot with grim.
# grim does not steal focus, so it also captures overlays and open menus.
# Saves, copies to the clipboard, and notifies (click the notification to edit).
set -uo pipefail

dir="$HOME/Pictures/screenshots"
mkdir -p "$dir"
file="$dir/screenshot-$(date +%Y%m%d_%H%M%S).png"

if grim "$file"; then
    wl-copy < "$file"
    "$HOME/.config/hypr/scripts/notify-shot.sh" "$file" &
else
    rm -f "$file"
    notify-send -u critical -a "Screenshot" "Screenshot" "Capture error"
fi
