#!/usr/bin/env bash
# Reapply the selected surface policy to the current pywal palette. Used by
# Settings when switching between Umbra's stable dark surfaces and legacy
# wallpaper-derived surfaces; it never changes the wallpaper itself.
set -uo pipefail

normalizer="$HOME/.config/hypr/scripts/pywal-normalize.py"
[ -x "$normalizer" ] || exit 0
[ -r "$HOME/.cache/wal/colors.json" ] || exit 0

"$normalizer" >/dev/null || exit 1
wal -R -n -q -s -t || exit 1

for script in yazi-pywal.sh cava-pywal.sh btop-pywal.sh discord-pywal.sh \
              spicetify-pywal.sh qt-pywal.py gtk-pywal.sh; do
    path="$HOME/.config/hypr/scripts/$script"
    [ -x "$path" ] && "$path" >/dev/null 2>&1 || true
done

pkill -SIGUSR1 -x kitty 2>/dev/null || true
hyprctl reload >/dev/null 2>&1 || true
