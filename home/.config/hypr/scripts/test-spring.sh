#!/usr/bin/env bash
# Calibrate LIVE the `windowsMove` spring (super + arrow keys).
#
# Requires the active Lua config (~/.config/hypr/hyprland.lua). It touches no
# file: it defines a new curve via `hyprctl eval` and hooks it in. It is undone
# with `hyprctl reload`.
#
# Usage:  ./test-spring.sh [config|shape|dry|nervous|lively|reset]
#       ./test-spring.sh <stiffness> <dampening>     # manually
#       ./test-spring.sh all                        # tries them in a row

set -euo pipefail

# zeta = dampening / (2*sqrt(stiffness*mass)), with mass = 1.
#   zeta = 1  -> arrives as fast as possible WITHOUT overshooting (law 5)
#   zeta < 1  -> bounces. It breaks law 5 on purpose.
aplicar() {
    local k="$1" d="$2" nota="${3:-}"
    local n="muelle$RANDOM"

    hyprctl eval "hl.curve('$n', { type = 'spring', stiffness = $k, dampening = $d, mass = 1 })
                  hl.animation({ leaf = 'windowsMove', enabled = true, speed = 4.4, spring = '$n' })" >/dev/null

    python3 -c "
import math
k, d = $k, $d
w0   = math.sqrt(k)
zeta = d / (2*math.sqrt(k))
# 2% settling time, approximation valid near critical
ts   = (5.83 if abs(zeta-1) < .15 else 4/zeta) / w0
print(f'  stiffness={k:<6} dampening={d:<6} zeta={zeta:.2f}  ~{ts*1000:.0f} ms  '
      f'{\"BOUNCES\" if zeta < 0.98 else \"no bounce\"}  $nota')
"
}

case "${1:-all}" in
  config)   aplicar 130 23   "<- what is in hyprland.lua" ;;
  shape)    aplicar 180 26.8 "<- right on the SHAPE step (440 ms)" ;;
  dry)      aplicar 250 31.6 "<- snappier" ;;
  nervous)  aplicar 340 36.9 "<- almost instant" ;;
  lively)   aplicar 180 21   "<- zeta 0.78, overshoots a touch (breaks law 5 on purpose)" ;;

  # Deprecated Spanish aliases, kept so existing users do not break.
  forma)    "$0" shape ;;
  seco)     "$0" dry ;;
  nervioso) "$0" nervous ;;
  vivo)     "$0" lively ;;
  todas)    "$0" all ;;

  reset)
    hyprctl reload >/dev/null
    echo "  Reloaded from hyprland.lua."
    ;;

  all)
    echo
    echo "  Each one stays for 12 s. Hit super+arrows -- and above all"
    echo "  CHAIN two or three in a row, that is where the spring shows."
    echo
    for p in config shape dry nervous lively; do "$0" "$p"; sleep 12; done
    echo
    echo "  Done. Reloading..."; hyprctl reload >/dev/null
    ;;

  [0-9]*)
    [ $# -eq 2 ] || { echo "usage: $0 <stiffness> <dampening>"; exit 1; }
    aplicar "$1" "$2" "<- manually"
    ;;

  *) echo "presets: config | shape | dry | nervous | lively | reset | all"
     echo "or manually: $0 <stiffness> <dampening>"; exit 1 ;;
esac
