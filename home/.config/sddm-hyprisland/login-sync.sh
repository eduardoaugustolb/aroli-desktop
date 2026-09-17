#!/usr/bin/env bash
# Syncs the login screen (SDDM hyprisland theme) with the current wallpaper.
#
# It copies TWO things, and both matter: the background and the accent pywal generated
# for hyprlock. That way the boot screen and the notch lock not only look alike,
# but change together and with the same color.
#
# RUNS AS YOUR USER. There is no root service behind it, and that is why
# this file exists. Before, /usr/local/bin/sddm-wallpaper-sync.sh did it,
# launched by a system .path: root read the PATH written in
# ~/.cache/wal/wal -a file any of your processes can rewrite- and
# passed it to ImageMagick. That is, root opened a file chosen by an
# unprivileged process, with ImageMagick delegates enabled (Arch's
# policy.xml restricts none) while leaving the result as 0644. A
# process running as you could use that to exfiltrate files only root can
# read. Now your user does the work and the only shared place is
# $SHARED, which root owns but your group can write; the worst thing you
# can write there is a JPEG that Qt then loads as the `sddm` user.
#
# It is called by set-wallpaper.sh, which is the only path through which the background
# changes (the Quickshell picker and awww-start.sh also go through it).
#
# Usage:  login-sync.sh [image]
#       Without an argument it takes the wallpaper pointed to by ~/.cache/wal/wal.
set -uo pipefail

SHARED=/var/lib/sddm-hyprisland
WAL_FILE="$HOME/.cache/wal/wal"
LOCK_COLORS="$HOME/.cache/wal/colors-hyprlock.conf"

# If the theme is not installed, this directory does not exist and there is nothing
# to sync. Exit with 0: this is a cosmetic extra, it must not break the
# background change of our caller.
[ -d "$SHARED" ] && [ -w "$SHARED" ] || exit 0

# --- background ------------------------------------------------------------
IMG="${1:-}"
if [ -z "$IMG" ] && [ -r "$WAL_FILE" ]; then
    IMG="$(cat "$WAL_FILE")"
fi

if [ -n "$IMG" ] && [ -f "$IMG" ]; then
    dest="$SHARED/current.jpg"
    tmp="$SHARED/.current.jpg.tmp"
    # Re-encoded to JPEG because the source wallpaper may be png or webp.
    #
    # The JPEG prefix: not decoration. ImageMagick picks the output format from
    # the EXTENSION, and here we first write to a temp file ending in .tmp, so
    # without it no conversion happens: the background came out as a 1.1 MB PNG inside
    # a file named current.jpg. With the prefix, a true 282 KB JPEG.
    #
    # Without ImageMagick cp is fine: the greeter loads with Qt, which looks at the content
    # not the extension, so a png named .jpg still shows.
    if command -v magick >/dev/null 2>&1; then
        magick "$IMG" "JPEG:$tmp" 2>/dev/null || cp -f -- "$IMG" "$tmp"
    else
        cp -f -- "$IMG" "$tmp"
    fi
    # Atomic rename: the greeter never sees a half-written file.
    if [ -s "$tmp" ]; then
        chmod 644 "$tmp" && mv -f -- "$tmp" "$dest"
    else
        rm -f -- "$tmp"
    fi
fi

# --- accent ----------------------------------------------------------------
# Single source of truth: the same file hyprlock reads. If you ever
# change the ~/.config/wal/templates/colors-hyprlock.conf template, login
# follows the change without touching anything else.
if [ -r "$LOCK_COLORS" ]; then
    acc="$(grep -oP '^\$accent\s*=\s*rgba\(\K[0-9a-fA-F]{6}' "$LOCK_COLORS" | head -1)"
    if [ -n "${acc:-}" ]; then
        tmp="$SHARED/.accent.tmp"
        printf '#%s\n' "$acc" >"$tmp" &&
            chmod 644 "$tmp" &&
            mv -f -- "$tmp" "$SHARED/accent"
    fi
fi

exit 0
