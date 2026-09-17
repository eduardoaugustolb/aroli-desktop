#!/usr/bin/env bash
# dynamic-cursors.sh - Shake to find enlarges the cursor, as on macOS. Loads
# hypr-dynamic-cursors, compiled locally against the commit pinned by
# hyprpm.toml for the exact Hyprland version, with only shake enabled: mode
# none disables unwanted cursor physics (stretching/rotation).
#
# When Hyprland/aquamarine update, the .so no longer matches the live compositor
# ("version mismatch"). This script finds the running Hyprland commit pin,
# recompiles, retries, and sends a notification. If the session predates the
# installed package, wait until the next login.

# Zoom is crisp when an SVG hyprcursor theme matching the cursor theme is in
# ~/.local/share/icons. It is not versioned because it is 340 KB of third-party
# binaries. Without it, the plugin enlarges the XCursor bitmap more softly.
REPO="$HOME/.local/share/hypr-dynamic-cursors"
SO="$REPO/out/dynamic-cursors.so"

[ -d "$REPO" ] || exit 0

cargar() { hyprctl plugin load "$SO" 2>&1; }

cargado() { hyprctl plugin list 2>/dev/null | grep -q dynamic-cursors; }

aplicar_config() {
    # Plugin configuration lives in hyprland.lua, not here: every reload resets
    # plugin options to defaults, so Lua reapplies them after the plugin loads.
    hyprctl reload >/dev/null 2>&1
}

pin_para_hyprland_vivo() {
    local hl
    hl=$(hyprctl -j version 2>/dev/null | jq -r '.commit')
    [ -n "$hl" ] || return 1
    local pin
    pin=$(sed -n "s/.*\"$hl\", \"\([0-9a-f]\{40\}\)\".*/\1/p" "$REPO/hyprpm.toml" | head -1)
    if [ -z "$pin" ]; then
        # The local hyprpm.toml does not know this version yet; fetch main.
        git -C "$REPO" fetch -q origin main 2>/dev/null &&
            git -C "$REPO" checkout -q origin/main -- hyprpm.toml 2>/dev/null
        pin=$(sed -n "s/.*\"$hl\", \"\([0-9a-f]\{40\}\)\".*/\1/p" "$REPO/hyprpm.toml" | head -1)
    fi
    [ -n "$pin" ] && printf '%s' "$pin"
}

compilar() {
    local pin
    pin=$(pin_para_hyprland_vivo) || return 1
    [ -n "$pin" ] || return 1
    git -C "$REPO" fetch -q origin "$pin" 2>/dev/null
    # -f discards the old local patch before changing commits.
    git -C "$REPO" checkout -q -f "$pin" 2>/dev/null || return 1
    # The pinned TOML lacks its own pin; keep it current for the next lookup.
    git -C "$REPO" checkout -q origin/main -- hyprpm.toml 2>/dev/null || true
    # Reapply the local highres.cpp patch so shake zoom loads the SVG theme even
    # with hyprcursor disabled. If upstream changes the line, build unpatched:
    # soft zoom is preferable to no build.
    sed -i 's/ || !\*PUSEHYPRCURSOR//' "$REPO/src/highres.cpp" 2>/dev/null || true
    make -s -C "$REPO" all >/dev/null 2>&1
}

# A fresh clone has the repo but not the .so, which must be built for this
# machine's Hyprland version. This happens only once.
if [ ! -f "$SO" ]; then
    notify-send -u low "Shake to find" "Building dynamic-cursors for the first time..." 2>/dev/null || true
    compilar || true
fi

salida=$(cargar)
case "$salida" in
*"version mismatch"*)
    notify-send -u low "Shake to find" "Rebuilding dynamic-cursors for this Hyprland..." 2>/dev/null || true
    compilar && salida=$(cargar)
    ;;
esac

if cargado; then
    aplicar_config
else
    notify-send -u normal "Shake to find" "dynamic-cursors could not load: ${salida:0:120}" 2>/dev/null || true
fi
