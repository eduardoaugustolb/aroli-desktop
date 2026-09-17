#!/usr/bin/env bash
# Migra symlinks do fork Diego para Umbra Liminal.
# Sem --apply, apenas mostra o plano.
set -euo pipefail

apply=0
source_dir="$HOME/.local/share/diegoMalagrida-dotfiles"
target_dir="$HOME/.local/share/umbra-liminal"

usage() {
    printf '%s\n' 'Uso: migrate-from-diego-rice.sh [--apply] [--source CAMINHO] [--target CAMINHO]'
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --apply) apply=1 ;;
        --source) shift; source_dir="${1:?--source precisa de caminho}" ;;
        --target) shift; target_dir="${1:?--target precisa de caminho}" ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'Opção desconhecida: %s\n' "$1" >&2; exit 2 ;;
    esac
    shift
done

repo_dir="$(git -C "$(dirname "$0")/.." rev-parse --show-toplevel)"
source_dir="$(realpath -m "$source_dir")"
target_dir="$(realpath -m "$target_dir")"

[ -d "$source_dir" ] || { printf 'Fork legado não encontrado: %s\n' "$source_dir" >&2; exit 1; }

if [ "$apply" -eq 1 ] && [ ! -e "$target_dir" ]; then
    git clone --origin origin "$repo_dir" "$target_dir"
fi

count=0
while IFS= read -r -d '' path; do
    resolved="$(realpath "$path" 2>/dev/null)" || continue
    case "$resolved" in
        "$source_dir"/*)
            relative="${resolved#"$source_dir"/}"
            # A inspeção usa o worktree atual como referência; --apply cria
            # dele um clone no destino antes de religar qualquer configuração.
            [ -e "$repo_dir/$relative" ] || continue
            replacement="$target_dir/$relative"
            count=$((count + 1))
            if [ "$apply" -eq 1 ]; then
                ln -sfn "$replacement" "$path"
                printf 'Migrado: %s\n' "$path"
            else
                printf 'Migraria: %s -> %s\n' "$path" "$replacement"
            fi
            ;;
    esac
done < <(find "$HOME/.config" -type l -print0)

[ "$apply" -eq 1 ] && printf '%d symlink(s) migrados. Relogue para aplicar.\n' "$count" \
    || printf '%d symlink(s) seriam migrados. Use --apply para confirmar.\n' "$count"
