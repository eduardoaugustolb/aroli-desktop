#!/usr/bin/env bash
# Migrates symlinks from the legacy fork to Umbra Liminal.
# Without --apply, it only shows the plan.
set -euo pipefail

apply=0
source_dir="$HOME/.local/share/diegoMalagrida-dotfiles"
target_dir="$HOME/.local/share/umbra-liminal"

usage() {
    printf '%s\n' 'Usage: migrate-from-legacy-rice.sh [--apply] [--source PATH] [--target PATH]'
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --apply) apply=1 ;;
        --source) shift; source_dir="${1:?--source needs a path}" ;;
        --target) shift; target_dir="${1:?--target needs a path}" ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'Unknown option: %s\n' "$1" >&2; exit 2 ;;
    esac
    shift
done

repo_dir="$(git -C "$(dirname "$0")/.." rev-parse --show-toplevel)"
source_dir="$(realpath -m "$source_dir")"
target_dir="$(realpath -m "$target_dir")"

[ -d "$source_dir" ] || { printf 'Legacy fork not found: %s\n' "$source_dir" >&2; exit 1; }

if [ "$apply" -eq 1 ] && [ ! -e "$target_dir" ]; then
    git clone --origin origin "$repo_dir" "$target_dir"
fi

count=0
while IFS= read -r -d '' path; do
    resolved="$(realpath "$path" 2>/dev/null)" || continue
    case "$resolved" in
        "$source_dir"/*)
            relative="${resolved#"$source_dir"/}"
            # Inspection uses the current worktree as reference; --apply clones
            # it to the destination before relinking any config.
            [ -e "$repo_dir/$relative" ] || continue
            replacement="$target_dir/$relative"
            count=$((count + 1))
            if [ "$apply" -eq 1 ]; then
                ln -sfn "$replacement" "$path"
                printf 'Migrated: %s\n' "$path"
            else
                printf 'Would migrate: %s -> %s\n' "$path" "$replacement"
            fi
            ;;
    esac
done < <(find "$HOME/.config" -type l -print0)

[ "$apply" -eq 1 ] && printf '%d symlink(s) migrated. Log back in to apply.\n' "$count" \
    || printf '%d symlink(s) would be migrated. Use --apply to confirm.\n' "$count"
