#!/usr/bin/env bash
# Eyedropper: picks a screen color and copies its hex value.
col=$(hyprpicker -a -f hex) || exit 0
[ -n "$col" ] && notify-send -t 2000 "󰃉 Color copied" "$col"
