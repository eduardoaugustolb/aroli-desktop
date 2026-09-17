#!/usr/bin/env bash
# Makes ALREADY OPEN GTK applications adopt the new palette without closing.
#
# GTK CSS files import ~/.cache/wal/colors-gtk.css rather than containing
# colors. GTK resolves that import once at startup and does not notice pywal
# rewrites it; changing the palette, touching CSS, and changing the theme fail.
#
# The appearance portal works: libadwaita and GTK rebuild their style cascade
# after an xdg-desktop-portal color-scheme change, rereading the user CSS import.
# Toggle the setting briefly, then restore it immediately.
#
# The cost is 0.15 s of light theme in open GTK applications (and Chrome). This
# is the minimum delay that propagates both changes; remove the set-wallpaper
# call if it ever becomes more distracting than useful.
set -uo pipefail

ESQUEMA="org.gnome.desktop.interface color-scheme"

actual=$(gsettings get ${ESQUEMA} 2>/dev/null) || exit 0
actual=${actual//\'/}
[ -n "$actual" ] || exit 0

case "$actual" in
  prefer-dark) otro=prefer-light ;;
  *)           otro=prefer-dark  ;;
esac

# Always restore the original scheme; leaving it light would be worse than no-op.
restaurar() { gsettings set ${ESQUEMA} "$actual" 2>/dev/null || true; }
trap restaurar EXIT INT TERM

gsettings set ${ESQUEMA} "$otro" 2>/dev/null || exit 0
sleep 0.15
