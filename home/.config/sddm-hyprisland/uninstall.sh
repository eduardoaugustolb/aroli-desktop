#!/bin/bash
# Restores SDDM to its previous theme and removes everything install.sh put in place.
set -euo pipefail

THEME=/usr/share/sddm/themes/hyprisland
SHARED=/var/lib/sddm-hyprisland

if [[ $EUID -ne 0 ]]; then
  echo "This script needs root: sudo $0" >&2
  exit 1
fi

rm -f /etc/sddm.conf.d/99-hyprisland.conf
rm -rf "$SHARED"

# In case anything is left from when a root service did this. It is not
# restored: it had the flaw that motivated the redesign -root opening a path
# written by an unprivileged process- and it is not worth reviving for a
# wallpaper.
if [[ -e /etc/systemd/system/sddm-wallpaper-sync.path ]]; then
  systemctl disable --now sddm-wallpaper-sync.path 2>/dev/null || true
  rm -f /etc/systemd/system/sddm-wallpaper-sync.path \
        /etc/systemd/system/sddm-wallpaper-sync.service
fi
rm -f /usr/local/bin/sddm-wallpaper-sync.sh
systemctl daemon-reload || true

echo 'SDDM is back to its default theme. The hyprisland theme is still in'
echo "$THEME in case you want it back: sudo ~/.config/sddm-hyprisland/install.sh"
echo
echo 'If you go back to the `silent` theme, its background no longer updates itself: it will stay'
echo 'with whatever it had set.'
