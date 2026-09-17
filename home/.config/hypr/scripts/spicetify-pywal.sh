#!/usr/bin/env bash
# Re-themes Spotify (spicetify) using the pywal palette. Called by set-wallpaper.sh.
#
# Uses the 'termspot' theme (github.com/fdeox/termspot): a CRT phosphor TUI.
# Its color.ini includes 19 custom schemes, so spicetify-colors.py only inserts
# or updates the [pywal] block with a vivid accent derived from the wallpaper's
# dominant hue, leaving the rest of the file unchanged.
#
# How color reaches an already-open Spotify instance:
#
#   1. Live (the usual path). spicetify-push-colors.py connects through the
#      DevTools WebSocket and rewrites documentElement's --spice-* variables.
#      It is immediate and unnoticeable: no restart, reload, or lost scroll.
#      Spotify must have started with --remote-debugging-port (set by the
#      ~/.local/share/applications .desktop file and spicetify-restart-spotify.sh).
#
#   2. Restarting (fallback). Only when the push fails: Spotify was simply
#      closed or was opened before the port existed. This was the old behavior.
#
# Why not 'spicetify watch': it performs a COMPLETE xpui reload (a 1-2 second
# flash and returns to the top of the scroll), leaves a process running, and
# its maintainer says it often fails on Linux (spicetify/cli#1091). The reason
# 'watch' missed changes in #2384 does NOT apply here: that user had
# ${xrdb:...} in color.ini and the file never changed; ours is rewritten with
# actual hex values.
set -u

command -v spicetify >/dev/null 2>&1 || exit 0

SCRIPTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GEN="$SCRIPTS/spicetify-colors.py"
PUSH="$SCRIPTS/spicetify-push-colors.py"
THEME_DIR="$HOME/.config/spicetify/Themes/termspot"
[ -r "$HOME/.cache/wal/colors.json" ] || exit 0
mkdir -p "$THEME_DIR"

# Regenerate color.ini (vivid accent) from the current pywal palette and compile
# it to disk. Refresh does not affect the open window, but stores the correct
# color for the next launch.
python3 "$GEN" "$THEME_DIR/color.ini" 2>/dev/null || exit 0
spicetify refresh >/dev/null 2>&1 || true

pgrep -x spotify >/dev/null 2>&1 || exit 0

# --- 1. live attempt ----------------------------------------------------------
if python3 "$PUSH" "$THEME_DIR/color.ini" >/dev/null 2>&1; then
  exit 0
fi

# --- 2. fallback: restart in ITS workspace without stealing focus ------------
if pgrep -x spotify >/dev/null 2>&1; then
  WS="$(hyprctl clients -j 2>/dev/null | python3 -c "
import json,sys
try: cs=json.load(sys.stdin)
except Exception: sys.exit()
for c in cs:
    if c.get('class')=='Spotify':
        w=c.get('workspace',{}).get('id')
        if w is not None: print(w)
        break" 2>/dev/null)"
  setsid -f "$SCRIPTS/spicetify-restart-spotify.sh" "$WS" >/dev/null 2>&1 &
fi
