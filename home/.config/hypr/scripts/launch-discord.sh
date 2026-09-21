#!/usr/bin/env bash
set -euo pipefail

# launch-discord.sh, abre o Discord.
# Ordem: vesktop (cliente do rice) → discord oficial → .desktop
# Discord do Omarchy (webapp) → web no navegador padrão.

for app in vesktop discord discord-canary; do
    if command -v "$app" >/dev/null 2>&1; then
        exec "$app" "$@"
    fi
done

if [ -f "$HOME/.local/share/applications/Discord.desktop" ]; then
    if gtk-launch Discord "$@" 2>/dev/null; then
        exit 0
    fi
fi

if command -v omarchy-launch-webapp >/dev/null 2>&1; then
    exec omarchy-launch-webapp "https://discord.com/channels/@me"
fi

exec xdg-open "https://discord.com/channels/@me"
