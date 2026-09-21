#!/usr/bin/env bash
set -euo pipefail

# launch-editor.sh, abre o editor de texto padrão.
# Ordem: .desktop default de text/plain (xdg-mime) → $VISUAL/$EDITOR
# gráficos → VS Code → editores gráficos comuns → $EDITOR de terminal
# (ou nvim) dentro do terminal padrão.

open_in_terminal() {
    if command -v xdg-terminal-exec >/dev/null 2>&1; then
        exec xdg-terminal-exec -- "$1"
    fi
    for t in ${TERMINAL:-} kitty ghostty alacritty foot gnome-terminal ptyxis xterm; do
        if [ -n "$t" ] && command -v "$t" >/dev/null 2>&1; then
            exec "$t" -e "$1"
        fi
    done
    return 1
}

default_desktop="$(xdg-mime query default text/plain 2>/dev/null || true)"
if [ -n "$default_desktop" ] && gtk-launch "$default_desktop" "$@" 2>/dev/null; then
    exit 0
fi

for ed in ${VISUAL:-} ${EDITOR:-}; do
    case "$ed" in
        code|codium|*code*|gnome-text-editor|gedit|kate|mousepad|leafpad)
            if command -v "$ed" >/dev/null 2>&1; then
                exec "$ed" "$@"
            fi
            ;;
    esac
done

for ed in code codium gnome-text-editor gedit kate mousepad; do
    if command -v "$ed" >/dev/null 2>&1; then
        exec "$ed" "$@"
    fi
done

for ed in ${EDITOR:-nvim} nvim vim vi nano; do
    if command -v "$ed" >/dev/null 2>&1; then
        open_in_terminal "$ed" && exit 0
    fi
done

notify-send "Nenhum editor encontrado" "Instale o neovim ou o VS Code" 2>/dev/null || true
exit 1
