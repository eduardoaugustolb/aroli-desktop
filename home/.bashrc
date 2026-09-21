#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# PATH das ferramentas do usuario. Mesmo motivo do bloco em ~/.zshrc: este
# arquivo e um symlink para o repo, entao instaladores (bun, rustup, uv) nao
# podem persistir PATH aqui. O que for particular vai em ~/.bashrc.local
# (seu; updates nunca tocam nele; carregado no fim deste arquivo).
for _rice_bin in "$HOME/.local/bin" "$HOME/.bun/bin" "${BUN_INSTALL:-$HOME/.bun}/bin" "$HOME/go/bin" "$HOME/.cargo/bin"; do
    [[ -d $_rice_bin ]] || continue
    case ":$PATH:" in
        *":$_rice_bin:"*) ;;
        *) PATH="$_rice_bin:$PATH" ;;
    esac
done
unset _rice_bin
if [[ -d $HOME/.local/share/mise/shims ]]; then
    case ":$PATH:" in
        *":$HOME/.local/share/mise/shims:"*) ;;
        *) PATH="$PATH:$HOME/.local/share/mise/shims" ;;
    esac
fi
export PATH

if command -v mise >/dev/null 2>&1; then
    eval "$(mise activate bash)"
fi

alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '
alias code='ELECTRON_ENABLE_WAYLAND=1 code --ozone-platform=wayland'

[ -r "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env"


fastfetch_ws_if_first() {
    # Necesitas hyprctl y jq
    command -v hyprctl >/dev/null 2>&1 || return
    command -v jq >/dev/null 2>&1 || return

    # Workspace actual
    local ws
    ws=$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.id') || return
    [[ -z "$ws" || "$ws" == "null" ]] && return

    # PID de la ventana de kitty que nos contiene (padre del shell)
    local kitty_pid
    kitty_pid=$(ps -o ppid= -p $$ --no-headers 2>/dev/null | tr -d ' ') || return
    [[ -z "$kitty_pid" ]] && return

    # Contamos OTRAS kitty en el mismo workspace (excluyendo esta)
    local others
    others=$(hyprctl clients -j 2>/dev/null \
        | jq --argjson ws "$ws" --argjson pid "$kitty_pid" '
            [ .[] 
              | select(.class == "kitty" and .workspace.id == $ws and .pid != $pid)
            ] 
            | length
        ') || return

    # Si no hay ninguna otra kitty en este workspace → fastfetch
    if [ "${others:-0}" -eq 0 ]; then
        fastfetch
    fi
}

# Llamamos a la función al abrir cada terminal
fastfetch_ws_if_first

alias cls='clear'

# Overrides pessoais (sobrevivem ao rice): ~/.bashrc e symlink para o repo,
# nao edite este arquivo para PATH/exports/aliases seus.
[[ -r $HOME/.bashrc.local ]] && . "$HOME/.bashrc.local"
