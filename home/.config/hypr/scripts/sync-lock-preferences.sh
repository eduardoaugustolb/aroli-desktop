#!/usr/bin/env bash
# Keep the lock screen's proportional type in step with Settings > Appearance.
# Hyprlock is not a QML client, so it consumes this tiny generated Hyprlang
# source at lock time instead of hard-coding a second, drifting preference.
set -euo pipefail

settings="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell-rice.json"
font="Adwaita Sans"

if [[ -r "$settings" ]] && command -v jq >/dev/null 2>&1; then
    candidate="$(jq -r '.fontUI // empty' "$settings" 2>/dev/null || true)"
    case "$candidate" in
        "Adwaita Sans"|"Google Sans Flex"|"Rubik"|"Red Hat Text"|"Space Grotesk"|"Readex Pro"|"Noto Sans")
            font="$candidate"
            ;;
    esac
fi

target="${XDG_CACHE_HOME:-$HOME/.cache}/wal/lock-preferences.conf"
mkdir -p "$(dirname "$target")"
tmp="${target}.tmp.$$"
printf '$lockFont = %s\n' "$font" > "$tmp"
mv -f "$tmp" "$target"
