#!/usr/bin/env bash
# Opens an EXISTING screenshot in satty for annotation. Called by the "Edit"
# notification action (see notify-shot.sh), but it also works standalone:
#   screenshot-edit.sh ~/Pictures/screenshots/loquesea.png
set -uo pipefail

img="${1:-}"
if [ ! -s "$img" ]; then
    notify-send -u critical -a "Screenshot" "Edit screenshot" "Image not found"
    exit 1
fi

dir="$HOME/Pictures/screenshots"
mkdir -p "$dir"

# Saves the annotated version separately: the original is untouched.
exec satty --filename "$img" \
           --output-filename "$dir/satty-$(date +%Y%m%d_%H%M%S).png" \
           --copy-command wl-copy --early-exit
