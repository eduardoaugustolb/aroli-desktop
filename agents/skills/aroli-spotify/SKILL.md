---
name: aroli-spotify
description: >
  Use for anything about Spotify theming on this rice: stuck color scheme,
  spicetify errors, backup mismatches, live recolor not reaching the open
  window, theme preview confusion. Triggers: spotify, spicetify, stuck
  scheme, gruvbox, termspot, aroli theme, remote-debugging-port, 9333,
  backup apply, refresh, xpui, color.ini.
---

# Spotify (spicetify, Aroli theme)

Config truth: `spicetify config` must read `current_theme aroli`,
`color_scheme pywal`. Compiled truth:
`/opt/spotify/Apps/xpui/spicetify-config.json` (`theme_name`, `scheme_name`,
baked scheme values). Runtime truth: the open window's CSS vars.

## The pipeline (check in this order)

1. Disk: `[pywal]` in `~/.config/spicetify/Themes/aroli/color.ini`
   matches `~/.cache/wal/colors.json` (see `aroli-wallpaper`).
2. Compiled: baked `[pywal]` matches disk. If not, `spicetify refresh`
   is silently a no-op when the backup mismatches the installed Spotify
   (`Spotify version and backup version are mismatched`). Fix:
   close Spotify, reinstall it (`yay -S spotify`), redo permissions
   (`setfacl -Rm/-Rdm u:$USER:rwX /opt/spotify`), run
   `spicetify backup apply`. Never `spicetify clear` on a patched tree.
3. Live: `curl -s --max-time 3 http://127.0.0.1:9333/json` must return
   JSON. Empty means Spotify launched without
   `--remote-debugging-port` (menu launches need the
   `~/.local/share/applications/spotify.desktop` override; keybind and
   terminal launches go through `launch-spotify.sh`, which carries the
   flags). Without the port, `spicetify-push-colors.py` always fails
   and `spicetify-pywal.sh` falls back to restarting Spotify.

## Traps

- The old termspot theme had an in-app terminal (`theme <name>`) that
  switches schemes at runtime only. A preview (`theme gruvbox`) survives
  everything except `theme reset`, restart, or a live push. If config,
  disk, and compiled all agree but the window disagrees, suspect this.
- `spicetify config a b` sets pairs positionally; a bare
  `spicetify config current_theme color_scheme` SETS current_theme to
  the literal string "color_scheme". Always pass full pairs and
  re-read the config afterwards.
- `spicetify refresh` exits 0 even when it compiles nothing. Read its
  output for "mismatched", do not trust the exit code.
