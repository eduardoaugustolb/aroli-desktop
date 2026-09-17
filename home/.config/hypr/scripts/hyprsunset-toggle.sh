#!/usr/bin/env bash
# Toggle night light (hyprsunset). Off = normal temperature.
if pgrep -x hyprsunset >/dev/null; then
    pkill -x hyprsunset
    notify-send -t 1500 "󰌵 Night light" "Off"
else
    hyprsunset -t 4000 >/dev/null 2>&1 &
    notify-send -t 1500 "󰃝 Night light" "On · 4000K"
fi
