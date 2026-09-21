#!/usr/bin/env bash
# Build a high-resolution vector companion for Aroli Pointer's shake-to-find zoom.
#
# The active cursor stays the original XCursor theme. This script starts from
# hyprcursor-util's official XCursor extraction to retain its exact hotspots
# and aliases, then rasterizes Aroli's matching SVG artwork once at 256 px.
# This avoids runtime SVG-renderer variations while keeping vector sharpness.
set -euo pipefail

icons="${XDG_DATA_HOME:-$HOME/.local/share}/icons"
extracted="$icons/extracted_Aroli"
source_dir="$icons/Aroli/src"
if [[ ! -d "$source_dir" ]]; then
    source_dir="$(find "$icons" -maxdepth 2 -path '*/Aroli.bak.*/src' -type d -print -quit 2>/dev/null || true)"
fi
# Compatibility with checkouts/installs from before the Umbra -> Aroli rename.
if [[ ! -d "$source_dir" ]]; then
    legacy="$icons/Umbra/src"
    if [[ -d "$legacy" ]]; then
        source_dir="$legacy"
    else
        legacy_bak="$(find "$icons" -maxdepth 2 -path '*/Umbra.bak.*/src' -type d -print -quit 2>/dev/null || true)"
        [[ -n "$legacy_bak" ]] && source_dir="$legacy_bak"
    fi
fi

[[ -d "$source_dir" ]] || { echo "Aroli Pointer SVG source is missing" >&2; exit 1; }
[[ -d "$extracted/hyprcursors" ]] || { echo "Run hyprcursor-util --extract on Aroli first" >&2; exit 1; }

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
cp -a "$extracted/hyprcursors" "$work/hyprcursors"
cat > "$work/manifest.hl" <<'EOF'
name = Aroli
description = Aroli Pointer vector zoom companion; hotspots and aliases from XCursor
version = 2.0
cursors_directory = hyprcursors
EOF

for dest in "$work/hyprcursors"/*; do
    [[ -d "$dest" ]] || continue
    shape="$(basename "$dest")"
    svg_name="$shape"
    [[ "$shape" == default ]] && svg_name="arrow"
    [[ "$shape" == pointer ]] && svg_name="hover"
    svg="$source_dir/$svg_name.svg"
    [[ -f "$svg" ]] || continue

    rsvg-convert --width 256 --height 256 "$svg" --output "$dest/image.png"
    # Preserve the live XCursor hotspot and alias declarations; replace only
    # the bitmap size variants with one high-resolution PNG rasterized from
    # Aroli's original SVG source.
    sed -i '/^define_size =/d' "$dest/meta.hl"
    printf '\ndefine_size = 256, image.png\n' >> "$dest/meta.hl"
done

hyprcursor-util --create "$work" --output "$icons"
