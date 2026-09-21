#!/usr/bin/env bash
set -euo pipefail

# launch-terminal.sh, abre o terminal padrão.
# Honra xdg-terminal-exec (o default do sistema) e cai para o terminal
# do rice (kitty) e outros comuns se ele não existir.

if command -v xdg-terminal-exec >/dev/null 2>&1; then
    exec xdg-terminal-exec "$@"
fi

# shellcheck disable=SC2086
for t in ${TERMINAL:-} kitty ghostty alacritty foot gnome-terminal ptyxis xterm; do
    if [ -n "$t" ] && command -v "$t" >/dev/null 2>&1; then
        exec "$t" "$@"
    fi
done

notify-send "Nenhum terminal encontrado" "Instale o kitty ou configure o xdg-terminal-exec" 2>/dev/null || true
exit 1
