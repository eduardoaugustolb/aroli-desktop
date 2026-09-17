#!/bin/bash
# Installs the hyprisland theme as the SDDM login screen.
#
# Idempotent: you can re-run it after editing ~/.config/sddm-hyprisland/Main.qml
# to republish your changes. It keeps a backup copy of anything it replaces.
#
# To undo: see uninstall.sh (restores SDDM to how it was, with `silent`).
set -euo pipefail

SRC=/home/eduardoaugustolb/.config/sddm-hyprisland
THEME=/usr/share/sddm/themes/hyprisland
SHARED=/var/lib/sddm-hyprisland
STAMP="$(date +%Y%m%d-%H%M%S)"

if [[ $EUID -ne 0 ]]; then
  echo "This script needs root: sudo $0" >&2
  exit 1
fi

# Who will keep the background up to date. Under sudo it is SUDO_USER; if someone
# logs in as real root there is nobody to grant the permission to, warned about at the end.
USUARIO="${SUDO_USER:-}"

# --- 1. the theme ----------------------------------------------------------
install -d -m 755 "$THEME" "$THEME/backgrounds"
install -m 644 "$SRC/Main.qml"          "$THEME/Main.qml"
install -m 644 "$SRC/metadata.desktop"  "$THEME/metadata.desktop"
# The background shipped with the theme is the QML fallback: what you see if the
# wallpaper has not been changed since install.
if [[ -f "$SRC/backgrounds/current.jpg" ]]; then
  install -m 644 "$SRC/backgrounds/current.jpg" "$THEME/backgrounds/current.jpg"
fi
# theme.conf only the first time: if it already exists it carries the live pywal accent.
if [[ ! -f "$THEME/theme.conf" ]]; then
  install -m 644 "$SRC/theme.conf" "$THEME/theme.conf"
fi

# --- 2. the shared place ---------------------------------------------------
#
# This is why this directory exists. The greeter runs as the `sddm` user,
# which cannot enter /home/<you> (0700), so the background has to live outside.
# The PREVIOUS way to solve it was a root service fetching it from ~/.cache/wal:
# root opening a path written by an unprivileged process and feeding it to
# ImageMagick. That has been removed.
#
# Now root owns the directory but your group can write to it, and the one copying
# is your user (login-sync.sh). The greeter only reads. Nobody gains privileges
# along the way: the most you can put in there is a JPEG.
install -d -m 755 "$SHARED"
if [[ -n "$USUARIO" ]]; then
  grupo="$(id -gn "$USUARIO")"
  chown "root:$grupo" "$SHARED"
  chmod 2775 "$SHARED"   # setgid: anything created inside inherits the group
fi

# --- 3. migration: out with the root service -------------------------------
# Earlier installs left behind a system unit and a script in /usr/local/bin.
# They are removed here so that updating the theme is enough.
if [[ -e /etc/systemd/system/sddm-wallpaper-sync.path ]]; then
  systemctl disable --now sddm-wallpaper-sync.path 2>/dev/null || true
  systemctl stop sddm-wallpaper-sync.service 2>/dev/null || true
  rm -f /etc/systemd/system/sddm-wallpaper-sync.path \
        /etc/systemd/system/sddm-wallpaper-sync.service
  echo "Removed the old syncer, which ran as root."
fi
if [[ -f /usr/local/bin/sddm-wallpaper-sync.sh ]]; then
  mv -f /usr/local/bin/sddm-wallpaper-sync.sh \
        "/usr/local/bin/sddm-wallpaper-sync.sh.retirado-$STAMP"
fi

# --- 4. tell SDDM to use the theme -----------------------------------------
install -d -m 755 /etc/sddm.conf.d
install -m 644 "$SRC/99-hyprisland.conf" /etc/sddm.conf.d/99-hyprisland.conf

# --- 5. first fill: current background and accent --------------------------
#
# AS THE USER, not as root: this is exactly the same path used later on every
# background change, so if something is broken it shows up here.
#
# The `|| true` is on purpose. The theme is ALREADY installed by now:
# copied, with the shared directory and the SDDM drop-in in place. This is only
# about applying it NOW instead of at the next wallpaper change, i.e. a
# convenience. Without the guard, a systemctl that cannot talk to systemd
# -seen in a container: "System has not been booted with systemd as init
# system"- would make the script exit with an error and the installer would report
# "the theme installer failed" when everything was actually in place.
systemctl daemon-reload || true
if [[ -n "$USUARIO" ]]; then
  sudo -u "$USUARIO" "$SRC/login-sync.sh" || true

  # Seed theme.conf with the current accent. The QML reads the live accent from
  # $SHARED/accent at startup, but paints the island before that read arrives:
  # leaving the good value here keeps the color from visibly jumping.
  if [[ -r "$SHARED/accent" ]]; then
    acc="$(grep -oE '^#[0-9a-fA-F]{6}$' "$SHARED/accent" || true)"
    if [[ -n "$acc" ]]; then
      sed -i "s/^accent=.*/accent=$acc/" "$THEME/theme.conf"
    fi
  fi
fi

echo
echo "Done. Theme installed in $THEME"
echo "Current accent:  $(grep '^accent=' "$THEME/theme.conf")"
echo "Background:      $(ls -la "$SHARED/current.jpg" 2>/dev/null || echo 'not yet, it will be set at the next wallpaper change')"
if [[ -z "$USUARIO" ]]; then
  echo
  echo "NOTE: launched without sudo, so it is unknown who will keep the background up to date."
  echo "Grant your user permission with:"
  echo "  sudo chown root:\$(id -gn) $SHARED && sudo chmod 2775 $SHARED"
fi
echo
echo "Do NOT restart sddm now: it would close your session. You will see it at the next boot."
