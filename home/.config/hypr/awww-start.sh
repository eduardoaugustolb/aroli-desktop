#!/bin/sh
#
# awww-start.sh -- starts the wallpaper daemon and guarantees a wallpaper is
# always set, including on a newly installed machine's first boot.
#
# This script also handles a clean installation where restore has no previous
# wallpaper, leaving a black screen even though the system colors are correct:
#
#   1. `install.sh` generates the palette with `wal -i "$img" -n -q`; `-n`
#      means generate the palette but do NOT set the wallpaper.
#   2. `awww restore` restores only the last displayed wallpaper, which does not
#      exist on a new machine because ~/.cache/awww is empty.
#   3. `awww restore` returns 0 even when it restored nothing.
#
# After restore, query what awww actually displays. Only outputs without an
# image receive a default wallpaper. On regular startup restore works and no
# re-theming occurs, avoiding the expensive set-wallpaper.sh reload chain.

uid="$(/usr/bin/id -u)"

if ! /usr/bin/pgrep -u "$uid" -x awww-daemon >/dev/null 2>&1; then
    /usr/bin/awww-daemon >/dev/null 2>&1 &
fi

# This runs in the background so Hyprland startup does not wait for the daemon
# socket.
(
    # Wait for the daemon. Unlike restore, `awww query` fails until its socket
    # exists and does not change state.
    listo=0
    intento=0
    while [ "$intento" -lt 50 ]; do
        if /usr/bin/awww query >/dev/null 2>&1; then
            listo=1
            break
        fi
        intento=$((intento + 1))
        /usr/bin/sleep 0.1
    done
    [ "$listo" = 1 ] || exit 0

    /usr/bin/awww restore >/dev/null 2>&1

    # Count every output, not only the first, so a second monitor without an
    # image also receives one.
    salidas="$(/usr/bin/awww query 2>/dev/null | /usr/bin/wc -l)"
    con_fondo="$(/usr/bin/awww query 2>/dev/null | /usr/bin/grep -c 'currently displaying: image:')"
    [ "${salidas:-0}" -gt 0 ] || exit 0
    [ "${con_fondo:-0}" -lt "${salidas:-0}" ] || exit 0   # A wallpaper is already set.

    # Prefer pywal's last image so the first wallpaper exactly matches the
    # existing palette. If it is unavailable, choose the first image in
    # ~/Pictures/wallpapers alphabetically, matching install.sh.
    img=""
    if [ -r "$HOME/.cache/wal/wal" ]; then
        img="$(/usr/bin/head -n 1 "$HOME/.cache/wal/wal" 2>/dev/null)"
        [ -n "$img" ] && [ -f "$img" ] || img=""
    fi
    if [ -z "$img" ]; then
        img="$(/usr/bin/find "$HOME/Pictures/wallpapers" -maxdepth 1 -type f \
                 \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) 2>/dev/null \
               | /usr/bin/sort | /usr/bin/head -n 1)"
    fi
    [ -n "$img" ] && [ -f "$img" ] || exit 0

    # set-wallpaper.sh also writes the state `wal -i` does not: hyprlock's
    # lockbg link, bar-strip.txt, and derived themes. Hyprland may not inherit
    # ~/.local/bin in PATH.
    if [ -x "$HOME/.config/hypr/set-wallpaper.sh" ]; then
        PATH="$HOME/.local/bin:/usr/local/bin:/usr/bin:$PATH"
        export PATH
        "$HOME/.config/hypr/set-wallpaper.sh" "$img" >/dev/null 2>&1
    else
        # Without the script, at least display something.
        /usr/bin/awww img "$img" >/dev/null 2>&1
    fi
) >/dev/null 2>&1 &

exit 0
