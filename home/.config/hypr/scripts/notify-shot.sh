#!/usr/bin/env bash
# Screenshot notification with an "Edit" action: clicking the notification (in
# the notch or control center) opens the image in satty.
#
# Note how this works: notify-send with -A implies --wait, so it remains alive
# waiting for a click. The capture script therefore launches it in the background.
# It also needs a timeout: our notification server (quickshell) does not expire
# them automatically, so without one a process would wait forever. Ten minutes
# is enough time to edit the screenshot.
set -uo pipefail

img="${1:-}"
[ -s "$img" ] || exit 0

# The body says it is clickable; otherwise no one discovers the action. The full
# path does not fit, so only the file name is omitted.
act=$(timeout 600 notify-send -a "Screenshot" -i "$img" -A "edit=Edit" \
        "Screenshot" "Copied to clipboard · click to edit" 2>/dev/null) || exit 0

[ "$act" = "edit" ] && exec "$HOME/.config/hypr/scripts/screenshot-edit.sh" "$img"
