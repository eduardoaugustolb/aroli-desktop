#!/usr/bin/env bash
# OCR: select area -> extract text -> clipboard.
# On a frozen screen, it can also read text from a menu or panel that would
# close when it loses focus.
set -uo pipefail

img=$(mktemp --suffix=.png)
trap 'rm -f "$img"' EXIT

"$HOME/.config/hypr/scripts/capture-region.sh" > "$img" || exit 0
[ -s "$img" ] || exit 0

txt=$(tesseract "$img" - -l spa+eng 2>/dev/null)
if [ -n "${txt// /}" ]; then
    printf '%s' "$txt" | wl-copy
    notify-send -t 2500 "OCR" "Text copied to clipboard"
else
    notify-send -t 2000 "OCR" "No text detected"
fi
