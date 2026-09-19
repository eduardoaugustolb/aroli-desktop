#!/usr/bin/env bash
# hypridle calls this when activity resumes after the DPMS timeout. Activity
# includes pointer movement/buttons and keyboard input; no separate input
# sniffer is needed (and one would not receive keys while hyprlock owns them).
#
# Keep this tiny and non-interactive: the first physical input must restore a
# visible lock screen immediately, before the user has to type their password.
exec hyprctl dispatch dpms on
