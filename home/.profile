export ELECTRON_ENABLE_WAYLAND=1

# PATH das ferramentas do usuario (POSIX sh: vale para login shells).
# Mesmo motivo do bloco em ~/.zshrc: este arquivo e um symlink para o repo,
# entao instaladores (bun, rustup, uv) nao podem persistir PATH aqui.
# Cada diretorio entra uma vez, so se existir. O que for particular vai em
# ~/.profile.local (seu; updates nunca tocam nele).
for _rice_bin in "$HOME/.local/bin" "$HOME/.bun/bin" "${BUN_INSTALL:-$HOME/.bun}/bin" "$HOME/go/bin" "$HOME/.cargo/bin"; do
    [ -d "$_rice_bin" ] || continue
    case ":$PATH:" in
        *":$_rice_bin:"*) ;;
        *) PATH="$_rice_bin:$PATH" ;;
    esac
done
unset _rice_bin
# mise shims no fim, como o omarchy faz em env-bootstrap.
if [ -d "$HOME/.local/share/mise/shims" ]; then
    case ":$PATH:" in
        *":$HOME/.local/share/mise/shims:"*) ;;
        *) PATH="$PATH:$HOME/.local/share/mise/shims" ;;
    esac
fi
export PATH

[ -r "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env"

# Overrides pessoais: carregados por ultimo, ganham de tudo acima.
[ -r "$HOME/.profile.local" ] && . "$HOME/.profile.local"
