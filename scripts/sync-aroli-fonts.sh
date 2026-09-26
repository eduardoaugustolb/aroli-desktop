#!/usr/bin/env bash
# sync-aroli-fonts.sh -- keeps the vendored Aroli OTFs in sync with upstream.
#
#   Upstream: github.com/getaroli/aroli
#     fonts/aroli/dist/AroliMonoNF-{Regular,Medium,SemiBold}.otf
#     fonts/aroli-sans/dist/AroliSans-{Regular,Medium,SemiBold,Bold}.otf
#   Vendored here:
#     home/.local/share/fonts/aroli-mono/
#     home/.local/share/fonts/aroli-sans/
#
# Modes (exactly one):
#   --check    read-only: download upstream to a temp dir and diff hashes.
#              Exit 0 when in sync, 1 when drift is found.
#   --apply    download, VERIFY, then replace the repo copies and bump the
#              lock file (scripts/aroli-fonts.lock). Refuses when the font
#              tree has uncommitted changes unless --force is given.
#   --install  copy the repo fonts into $HOME/.local/share/fonts and rebuild
#              the font cache. No network. This is what a local update runs
#              after pulling.
#
# Safety: never touches anything outside the two font dirs (+ lock file on
# --apply). Downloads are verified before they reach the tree: allowlisted
# filenames only, OTTO magic, minimum size, and fc-scan family check when
# fontconfig is present. No sudo, no auto-commit, no push.
set -euo pipefail

UPSTREAM_OWNER="eduardoaugustolb"
UPSTREAM_REPO="aroli"
UPSTREAM_BRANCH="main"
RAW_BASE="https://raw.githubusercontent.com/${UPSTREAM_OWNER}/${UPSTREAM_REPO}/${UPSTREAM_BRANCH}"
REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LOCK_FILE="$REPO/scripts/aroli-fonts.lock"
MONO_DIR="$REPO/home/.local/share/fonts/aroli-mono"
SANS_DIR="$REPO/home/.local/share/fonts/aroli-sans"

MONO_FILES=(AroliMonoNF-Regular.otf AroliMonoNF-Medium.otf AroliMonoNF-SemiBold.otf)
SANS_FILES=(AroliSans-Regular.otf AroliSans-Medium.otf AroliSans-SemiBold.otf AroliSans-Bold.otf)

MODE=""
FORCE=0
for arg in "$@"; do
    case "$arg" in
        --check|--apply|--install) MODE="$arg" ;;
        --force) FORCE=1 ;;
        -h|--help)
            sed -n '1,/^set -/p' "$0" | sed 's/^# \{0,1\}//'
            exit 0 ;;
        *) echo "unknown argument: $arg (try --help)" >&2; exit 2 ;;
    esac
done
[ -n "$MODE" ] || { echo "usage: $0 --check | --apply [--force] | --install" >&2; exit 2; }

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing required tool: $1" >&2; exit 2; }; }
need curl; need sha256sum; need python3

tmp="$(mktemp -d "${TMPDIR:-/tmp}/aroli-fonts.XXXXXXXX")"
trap 'rm -rf "$tmp"' EXIT

fetch() { # $1 = upstream dist path, $2 = dest file
    curl -fsSL --retry 3 --max-time 120 -o "$2" "$RAW_BASE/$1"
}

verify_otf() { # $1 = file, $2 = label
    local size magic
    size="$(stat -c%s "$1" 2>/dev/null || stat -f%z "$1")"
    [ "$size" -ge 10240 ] || { echo "REJECT $2: too small (${size} bytes)" >&2; return 1; }
    magic="$(python3 -c 'import sys; print(open(sys.argv[1],"rb").read(4))' "$1")"
    [ "$magic" = "b'OTTO'" ] || { echo "REJECT $2: bad magic $magic (not OTF)" >&2; return 1; }
    if command -v fc-scan >/dev/null 2>&1; then
        # Captured first: piping fc-scan straight into `grep -q` lets grep
        # close the pipe on the first match, fc-scan dies of SIGPIPE, and
        # `set -o pipefail` turns that into a false REJECT.
        scan_out="$(fc-scan "$1" 2>/dev/null || true)"
        grep -qi "aroli" <<<"$scan_out" \
            || { echo "REJECT $2: fc-scan family is not Aroli" >&2; return 1; }
    fi
    chmod 644 "$1"
}

upstream_commit() {
    git ls-remote "https://github.com/${UPSTREAM_OWNER}/${UPSTREAM_REPO}.git" \
        "refs/heads/${UPSTREAM_BRANCH}" 2>/dev/null | awk '{print $1}'
}

case "$MODE" in
--check)
    drift=0
    for f in "${MONO_FILES[@]}"; do
        fetch "fonts/aroli/dist/$f" "$tmp/$f"
        verify_otf "$tmp/$f" "upstream mono/$f" || exit 1
        if cmp -s "$tmp/$f" "$MONO_DIR/$f"; then
            printf 'same  mono/%s\n' "$f"
        else
            printf 'DRIFT mono/%s (local %s)\n' "$f" "$(sha256sum < "$MONO_DIR/$f" | cut -d' ' -f1 | cut -c1-12)"
            drift=1
        fi
    done
    for f in "${SANS_FILES[@]}"; do
        fetch "fonts/aroli-sans/dist/$f" "$tmp/$f"
        verify_otf "$tmp/$f" "upstream sans/$f" || exit 1
        if cmp -s "$tmp/$f" "$SANS_DIR/$f"; then
            printf 'same  sans/%s\n' "$f"
        else
            printf 'DRIFT sans/%s (local %s)\n' "$f" "$(sha256sum < "$SANS_DIR/$f" | cut -d' ' -f1 | cut -c1-12)"
            drift=1
        fi
    done
    if [ "$drift" = 1 ]; then
        echo "fonts are BEHIND upstream; run $0 --apply" >&2
        exit 1
    fi
    echo "fonts are in sync with upstream."
    ;;
--apply)
    if [ "$FORCE" = 0 ] && ! git -C "$REPO" diff --quiet -- home/.local/share/fonts/ scripts/aroli-fonts.lock; then
        echo "refusing: uncommitted changes under home/.local/share/fonts/ (pass --force to override)" >&2
        exit 1
    fi
    for f in "${MONO_FILES[@]}"; do
        fetch "fonts/aroli/dist/$f" "$tmp/$f"
        verify_otf "$tmp/$f" "upstream mono/$f" || exit 1
    done
    for f in "${SANS_FILES[@]}"; do
        fetch "fonts/aroli-sans/dist/$f" "$tmp/$f"
        verify_otf "$tmp/$f" "upstream sans/$f" || exit 1
    done
    commit="$(upstream_commit)"
    [ -n "$commit" ] || { echo "could not resolve upstream commit; lock not updated, fonts NOT applied" >&2; exit 1; }
    for f in "${MONO_FILES[@]}"; do cp -a "$tmp/$f" "$MONO_DIR/$f"; done
    for f in "${SANS_FILES[@]}"; do cp -a "$tmp/$f" "$SANS_DIR/$f"; done
    {
        printf '{\n'
        printf '  "upstream": "%s/%s@%s",\n' "$UPSTREAM_OWNER" "$UPSTREAM_REPO" "$UPSTREAM_BRANCH"
        printf '  "upstream_commit": "%s",\n' "$commit"
        printf '  "synced_at": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        printf '  "files": {\n'
        first=1
        for f in "${MONO_FILES[@]}"; do
            [ "$first" = 1 ] || printf ',\n'
            printf '    "aroli-mono/%s": "%s"' "$f" "$(sha256sum < "$MONO_DIR/$f" | cut -d' ' -f1)"
            first=0
        done
        for f in "${SANS_FILES[@]}"; do
            printf ',\n    "aroli-sans/%s": "%s"' "$f" "$(sha256sum < "$SANS_DIR/$f" | cut -d' ' -f1)"
        done
        printf '\n  }\n}\n'
    } > "$LOCK_FILE"
    echo "applied upstream $commit; review with: git -C \"$REPO\" status --short -- home/.local/share/fonts/"
    ;;
--install)
    mkdir -p "$HOME/.local/share/fonts/aroli-mono" "$HOME/.local/share/fonts/aroli-sans"
    cp -a "$MONO_DIR"/AroliMonoNF-*.otf "$HOME/.local/share/fonts/aroli-mono/"
    cp -a "$SANS_DIR"/AroliSans-*.otf "$HOME/.local/share/fonts/aroli-sans/"
    if command -v fc-cache >/dev/null 2>&1; then
        fc-cache -f "$HOME/.local/share/fonts" >/dev/null 2>&1 && echo "font cache rebuilt"
    else
        echo "no fc-cache (fontconfig missing); log back in to pick up the fonts" >&2
    fi
    ;;
esac
