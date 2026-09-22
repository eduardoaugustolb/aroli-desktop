---
name: aroli-wallpaper
description: >
  Use when the wallpaper, the pywal palette, or any derived theme did not
  follow a change: terminal, bar, Quickshell, Spotify, Discord, btop, cava,
  yazi, Qt/GTK, SDDM, or lock screen showing stale colors. Triggers:
  wallpaper, background, pywal, wal, colors.json, set-wallpaper, palette,
  theme not changing, wrong accent, stale colors, okthief.
---

# Wallpaper pipeline

`set-wallpaper.sh <image>` is the only entry point. It serializes runs with
a lock, generates the palette (`wal --backend okthief --saturate 0.2`,
fallback default backend), normalizes slots (`pywal-normalize.py`), syncs
SDDM, pushes Spotify FIRST, transitions with `awww`, then reloads the rest.
Quickshell recolors itself by watching `~/.cache/wal/colors.json`.

## Debugging order (compare the three stages)

1. `jq -r .wallpaper ~/.cache/wal/colors.json` — is the palette from the
   wallpaper on screen? If old, re-run `set-wallpaper.sh` with the image.
2. `~/.config/spicetify/Themes/aroli/color.ini` `[pywal]` vs `colors.json`
   — `spicetify-colors.py` rewrites it; mismatch means the generator failed.
3. The app itself: for Spotify see `aroli-spotify`. Terminals recolor on
   `SIGUSR1` to kitty; rofi/btop/hyprlock read colors at launch (relaunch,
   no daemon to poke).

## Rules

- Never hand-edit the `[pywal]` block or `colors.json`; regenerate.
- `~/.cache/wal/bar-strip.txt` (real strip color for the bar) is written by
  the same script; if missing, Colors.qml falls back to pywal background.
- Failures notify via `notify-send`; the per-app log for Spotify is
  `~/.cache/spicetify-pywal.log`.
