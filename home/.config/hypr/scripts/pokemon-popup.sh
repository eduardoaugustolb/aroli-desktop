#!/usr/bin/env bash
# Floating popup that summons a random animated Pokemon (SUPER+O).
# Any keypress (or 10 seconds) closes it.
d="$HOME/.cache/pokeanim/.box"
shopt -s nullglob
gifs=("$d"/*.gif)
[ ${#gifs[@]} -eq 0 ] && exit 0
gif="${gifs[RANDOM % ${#gifs[@]}]}"
printf '\033[2J\033[H\n'
kitten icat --align center --loop -1 "$gif" 2>/dev/null
read -rsn1 -t 10
