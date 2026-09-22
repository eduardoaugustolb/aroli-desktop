#!/usr/bin/env bash
set -euo pipefail

# launch-spotify.sh, abre o Spotify.
# Ordem: cliente nativo → flatpak.
#
# As flags abrem a porta do DevTools (9333): sem ela o spicetify-pywal.sh não
# consegue repintar a janela aberta a cada troca de wallpaper (o push falha e
# o Spotify fica preso nas cores antigas). São as mesmas flags do
# spicetify-restart-spotify.sh e do override em
# ~/.local/share/applications/spotify.desktop (que cobre os launches do menu;
# este script cobre o atalho Super+Alt+M e o terminal).
FLAGS="--remote-debugging-port=9333 --remote-allow-origins=http://127.0.0.1:9333"

if command -v spotify >/dev/null 2>&1; then
    # FLAGS sem aspas de propósito: é uma lista de argumentos, não um só.
    # shellcheck disable=SC2086
    exec spotify $FLAGS "$@"
fi

if command -v flatpak >/dev/null 2>&1 && flatpak info com.spotify.Client >/dev/null 2>&1; then
    # shellcheck disable=SC2086
    exec flatpak run com.spotify.Client $FLAGS "$@"
fi

notify-send "Spotify não encontrado" "Instale o pacote spotify" 2>/dev/null || true
exit 1
