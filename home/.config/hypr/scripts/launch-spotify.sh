#!/usr/bin/env bash
set -euo pipefail

# launch-spotify.sh - abre o Spotify.
# Ordem: cliente nativo → flatpak.

if command -v spotify >/dev/null 2>&1; then
    exec spotify "$@"
fi

if command -v flatpak >/dev/null 2>&1 && flatpak info com.spotify.Client >/dev/null 2>&1; then
    exec flatpak run com.spotify.Client "$@"
fi

notify-send "Spotify não encontrado" "Instale o pacote spotify" 2>/dev/null || true
exit 1
