#!/usr/bin/env bash
# Small values for hyprlock. They do not depend on the global locale: the
# session uses LC_TIME=C while the rest of the interface presents dates in the
# rice language (pt-BR by default).
set -uo pipefail

# Language comes from the same language.conf loaded by hyprlock, so the notch
# and this line cannot end up using different languages.
. "${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts/lang.sh" 2>/dev/null || RICE_LANG="${RICE_LANG:-pt-BR}"

case "${1:-}" in
  date)
    if [[ "$RICE_LANG" == en ]]; then
      # English needs no table: ask date directly with explicit LC_ALL=C. Do
      # not inherit an overridden Spanish locale into an otherwise English UI.
      printf '%s · %d %s\n' "$(LC_ALL=C date +%A)" "$(date +%-d)" "$(LC_ALL=C date +%B)"
    elif [[ "$RICE_LANG" == pt-BR ]]; then
      days=(segunda-feira terça-feira quarta-feira quinta-feira sexta-feira sábado domingo)
      months=(janeiro fevereiro março abril maio junho julho agosto setembro outubro novembro dezembro)
      day_index=$((10#$(date +%u) - 1))
      month_index=$((10#$(date +%m) - 1))
      day_name="${days[$day_index]}"
      printf '%s · %d de %s\n' "${day_name^}" "$(date +%-d)" "${months[$month_index]}"
    else
      days=(lunes martes miércoles jueves viernes sábado domingo)
      months=(enero febrero marzo abril mayo junio julio agosto septiembre octubre noviembre diciembre)
      day_index=$((10#$(date +%u) - 1))
      month_index=$((10#$(date +%m) - 1))
      day_name="${days[$day_index]}"
      printf '%s · %d de %s\n' "${day_name^}" "$(date +%-d)" "${months[$month_index]}"
    fi
    ;;

  battery)
    shopt -s nullglob
    batteries=(/sys/class/power_supply/BAT*)
    if ((${#batteries[@]} == 0)); then
      exit 0
    fi

    battery="${batteries[0]}"
    capacity="$(<"$battery/capacity")"
    status="$(<"$battery/status")"
    if [[ "$status" == "Charging" || "$status" == "Full" ]]; then
      icon="󰂄"
    else
      icon="󰁹"
    fi
    printf '%s  %s%%\n' "$icon" "$capacity"
    ;;
esac
