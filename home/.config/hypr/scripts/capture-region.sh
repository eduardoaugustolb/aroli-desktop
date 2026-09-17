#!/usr/bin/env bash
# Region selection ON THE FROZEN SCREEN. Writes the PNG to stdout.
#
# THE PROBLEM: slurp steals focus, closing everything that depends on it before
# you capture: the notch (Super+D), launcher, context menu, or dropdown. The
# resulting screenshot showed an empty desktop where the target had been.
#
# THE SOLUTION: hyprpicker places a COPY of the screen above everything. From
# that point on, what is below may close, move, or disappear: selection and
# cropping apply to the image, not the live desktop.
#
# It also records which notch panel was open and restores it afterward. Freezing
# moves focus away and cancels its grab, so capturing no longer closes Control
# Center.
#
# Exits with 1 when canceled (Esc or a click without dragging).
set -uo pipefail

freeze=""
panel=""

salir() {
    [ -n "$freeze" ] && kill "$freeze" 2>/dev/null
    freeze=""
    # Unfreeze before restoring, or the panel would open below the image.
    [ -n "$panel" ] && qs ipc call notch restore "$panel" >/dev/null 2>&1
    return 0
}
trap salir EXIT INT TERM HUP

if command -v qs >/dev/null 2>&1; then
    panel=$(qs ipc call notch current 2>/dev/null | tr -d '"[:space:]')
fi

if command -v hyprpicker >/dev/null 2>&1; then
    # -r freezes inactive monitors too; -z removes the eyedropper magnifier.
    # A timeout is the safety net: if this script dies badly (SIGKILL, so the
    # trap cannot run), hyprpicker would otherwise leave the screen frozen.
    timeout 180 hyprpicker -r -z >/dev/null 2>&1 &
    freeze=$!
    # The frozen layer must be above slurp, or its selection is drawn beneath it.
    sleep 0.2
fi

geom=$(slurp) || exit 1
[ -n "$geom" ] || exit 1

grim -g "$geom" -
