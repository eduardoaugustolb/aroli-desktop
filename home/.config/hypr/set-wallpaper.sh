#!/usr/bin/env bash
# set-wallpaper.sh <image> - changes the wallpaper and re-themes EVERYTHING (pywal) live.
set -uo pipefail
IMG="${1:-}"
[ -z "$IMG" ] && { echo "usage: set-wallpaper.sh <image>"; exit 1; }
[ -f "$IMG" ] || { echo "does not exist: $IMG"; exit 1; }
IMG="$(realpath -- "$IMG")" || exit 1

# Serializes the entire pipeline: the picker launches this script with
# execDetached for each selection, and two concurrent wal runs leave a MIXED
# desktop (A's wallpaper with B's palette, half-written colors.json). With the
# lock, each selection waits for the previous one rather than overwriting it.
# Same pattern as pacman-updates.sh. Background jobs close fd 9 (9>&-) so they
# do not retain the lock beyond this script.
#
# The `if` is important: a standalone failing `exec 9>...` -for example, due
# to another user's lock in /tmp- terminates this script silently, leaving the
# wallpaper unchanged. This continues without the lock if it cannot be opened.
if exec 9>"${XDG_RUNTIME_DIR:-/tmp}/set-wallpaper.lock" 2>/dev/null; then
    flock 9
fi

# --saturate 0.2: slightly enhances the palette without making it neon. Pywal
# already produces vivid colors from colorful wallpapers; high values (0.4-0.5)
# add that amount to EVERY color's HLS saturation (S=0.9-1.0 in almost every
# slot), making the terminal, yazi, cava, and fzf fluorescent. 0.2 retains the
# wallpaper's character. install.sh uses the same value so the first launch
# looks like the first wallpaper change.
#
# Pinned backend: okthief clusters by dominant areas, so small vivid details
# don't hijack the accent slots. Falls back to pywal's default when okthief
# is missing or fails. Whatever palette comes out, pywal-normalize.py then
# reassigns the chromatic slots by hue (a green detail must not land in the
# red slot) and `wal -R` re-exports every template from the normalized file.
if ! wal -i "$IMG" --backend okthief --saturate 0.2 -n -q -s -t; then
  if ! wal -i "$IMG" --saturate 0.2 -n -q -s -t; then
    notify-send -u critical "Dynamic theme" "Pywal could not generate the palette" 2>/dev/null || true
    exit 1
  fi
fi
if [ -x "$HOME/.config/hypr/scripts/pywal-normalize.py" ]; then
  "$HOME/.config/hypr/scripts/pywal-normalize.py" >/dev/null 2>&1 \
    && wal -R -n -q -s -t || true
fi
# The login screen (SDDM's hyprisland theme) follows the wallpaper like the
# lock screen. It runs as the user, not root: see login-sync.sh's header
# comment. It runs in the background because it re-encodes the image and should
# not delay the visible wallpaper transition.
[ -x "$HOME/.config/sddm-hyprisland/login-sync.sh" ] &&
    "$HOME/.config/sddm-hyprisland/login-sync.sh" "$IMG" >/dev/null 2>&1 9>&- &

# Actual color of the strip where the bar lives. This is needed because the bar
# has no surface of its own: its elements draw directly over the wallpaper, so
# visibility must be measured against what is BEHIND them. Pywal's `background`
# is unsuitable: it is a darkened palette derivative, not part of the image
# (measured on this wallpaper: 0.011 luminance versus 0.087 for the real strip,
# eight times darker), so using it dims elements where the wallpaper is light.
# This averages the image's top 5% and writes it where Colors.qml watches it.
# If magick fails, the file stays empty and Colors falls back to pywal's
# background as before.
magick "$IMG" -gravity north -crop '100%x5%+0+0' +repage -alpha off -resize 1x1! txt:- 2>/dev/null \
  | awk 'NR==2 && $3 ~ /^#[0-9A-Fa-f]{6}$/ {print $3}' > "$HOME/.cache/wal/bar-strip.txt" || true

# Spotify, FIRST among reloaded components and in the background.
#
# It was last in the list and it showed: the bar and terminals had already
# changed color while Spotify remained blue for more than a second. Measured
# from desktop video while changing the wallpaper with Spotify in front: the
# wallpaper appeared, the bar changed, and Spotify repainted 1.3-1.7 seconds
# later. It is not slow -the DevTools push takes 0.07 seconds- it was simply
# queued after yazi, cava, btop, and discord.
#
# It now runs here with the newly written palette and BEFORE the wallpaper
# transition begins, in the background so it does not delay it. This lets the
# wallpaper and the largest window on screen change together, making the whole
# system read as one.
~/.config/hypr/scripts/spicetify-pywal.sh >/dev/null 2>&1 9>&- &

# The wallpaper is visual; an awww failure does not invalidate the new palette.
# ilyamiro-style apply: random transition + from center + 144fps + 1s
awww_transitions=(simple fade left right top bottom wipe grow center outer random wave)
awww_rt="${awww_transitions[RANDOM % ${#awww_transitions[@]}]}"
awww img "$IMG" --transition-type "$awww_rt" --transition-pos 0.5,0.5 --transition-fps 144 --transition-duration 1 >/dev/null 2>&1 || awww img "$IMG" >/dev/null 2>&1 || true

# Reload live daemons.
# Quickshell (bar + notch) does NOT need a reload: Colors.qml watches
# ~/.cache/wal/colors.json and recolors itself.
scope_enabled() {
  command -v jq >/dev/null 2>&1 || return 0
  jq -e --arg key "$1" '.[$key] // true' "$HOME/.config/quickshell-rice.json" >/dev/null 2>&1
}
scope_enabled paletteScopeTerminal && pkill -SIGUSR1 -x kitty 2>/dev/null || true
scope_enabled paletteScopeHyprland && hyprctl reload >/dev/null 2>&1 || true
# swaync removed on 2026-08-05: Quickshell provides the notification server
~/.config/hypr/scripts/yazi-pywal.sh 2>/dev/null || true
~/.config/hypr/scripts/cava-pywal.sh 2>/dev/null || true
# VS Code removed on 2026-08-11: pywal theming looked bad in every variation,
# and an entire editor cannot look good from five wallpaper colors. It retains
# its default theme. The script is stored in ~/.audit-backups/2026-08-12/bak-files/.
~/.config/hypr/scripts/btop-pywal.sh 2>/dev/null || true
# Qt applications: write qt5ct and qt6ct palettes and kdeglobals color
# sections. Both families recolor WITHOUT restarting because their platform
# theme watches the .conf and the script rewrites it while preserving the inode,
# which is what lets the watcher detect it; with the usual temp + rename trick,
# it never does.
scope_enabled paletteScopeGtkQt && ~/.config/hypr/scripts/qt-pywal.py >/dev/null 2>&1 || true
# Also update already-open GTK/libadwaita applications through the appearance portal.
scope_enabled paletteScopeGtkQt && ~/.config/hypr/scripts/gtk-pywal.sh >/dev/null 2>&1 || true
~/.config/hypr/scripts/discord-pywal.sh 2>/dev/null || true
~/.config/hypr/scripts/aroli-newtab-pywal.sh 2>/dev/null || true
# (spicetify was already launched above, before the wallpaper transition)
# Reorders Pokemon sprites for the new palette (~0.1 s) so the next terminal
# immediately picks matching ones. If it fails, pokefetch uses randomness.
# (absolute path: Hyprland does not always inherit ~/.local/bin in PATH)
[ -x "$HOME/.local/bin/poke-theme" ] && "$HOME/.local/bin/poke-theme" rank -q >/dev/null 2>&1 9>&- &
# (rofi, btop, wlogout, and hyprlock read colors on launch -> no reload)
exit 0
