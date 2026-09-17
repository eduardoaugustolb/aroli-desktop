#!/usr/bin/env python3
# pywal-normalize.py — reassigns pywal's chromatic slots by hue.
#
# pywal clusters the wallpaper and fills the ANSI slots by lightness/order,
# with no hue semantics: a small green detail can land in color1 (the red
# slot), so terminal errors render green and yazi's cut marker turns green.
#
# This script finds the optimal assignment of color1-6 to the canonical ANSI
# hue anchors (red, green, yellow, blue, magenta, cyan) minimizing total
# circular hue distance (6! = 720 permutations, trivial), then applies the
# same permutation to the bright mirrors color9-14 (pywal keeps them aligned
# with 1-6). color0/7/8/15 and special.* are untouched.
#
# Gray palettes (max saturation below 0.12) are left alone: hue assignment
# on near-grays is meaningless noise.
#
# After rewriting colors.json, templates must be re-exported from it with:
#   wal -R -n -q -s -t
# which replays every template and sequence from the normalized palette.
#
# Usage: pywal-normalize.py [colors.json]
#   (default ~/.cache/wal/colors.json). Prints what changed. Idempotent:
#   a normalized palette is a fixed point.
import colorsys
import itertools
import json
import os
import sys

# Canonical ANSI hue anchors (HLS fractions) for slots color1..color6.
ANCHORS = (0.0, 1 / 3, 1 / 6, 2 / 3, 5 / 6, 0.5)
GRAY_SAT = 0.12


def hls(hex_color):
    hex_color = hex_color.lstrip("#")
    r, g, b = (int(hex_color[i:i + 2], 16) / 255 for i in (0, 2, 4))
    return colorsys.rgb_to_hls(r, g, b)


def circ(a, b):
    d = abs(a - b) % 1.0
    return min(d, 1.0 - d)


def normalize(colors):
    """Return the slot->color permutation that best matches ANSI anchors.

    Returns (perm, changed): perm[slot] is the index into `colors` that
    belongs in that slot. Identity when already aligned or too gray.
    """
    hues = [hls(c)[0] for c in colors]
    sats = [hls(c)[2] for c in colors]
    if max(sats) < GRAY_SAT:
        return tuple(range(6)), False
    best = tuple(range(6))
    best_cost = sum(circ(hues[i], ANCHORS[i]) for i in range(6))
    for perm in itertools.permutations(range(6)):
        cost = sum(circ(hues[i], ANCHORS[slot]) for slot, i in enumerate(perm))
        if cost < best_cost:
            best_cost = cost
            best = perm
    # perm maps slot -> color index; same permutation mirrors onto color9-14,
    # keeping each group's own values (never copy 1-6 over the brights).
    return best, best != tuple(range(6))


def main(argv):
    src = argv[1] if len(argv) > 1 else \
        os.path.join(os.path.expanduser("~"), ".cache/wal/colors.json")
    try:
        with open(src) as f:
            data = json.load(f)
    except Exception as e:
        sys.stderr.write("pywal-normalize: cannot read %s: %s\n" % (src, e))
        return 1
    try:
        group = [data["colors"]["color%d" % i] for i in range(1, 7)]
        brights = [data["colors"]["color%d" % i] for i in range(9, 15)]
    except KeyError as e:
        sys.stderr.write("pywal-normalize: palette missing slot %s\n" % e)
        return 1
    perm, changed = normalize(group)
    if not changed:
        print("pywal-normalize: slots already hue-aligned, nothing to do")
        return 0
    for slot, idx in enumerate(perm):
        data["colors"]["color%d" % (slot + 1)] = group[idx]
        data["colors"]["color%d" % (slot + 9)] = brights[idx]
    tmp = src + ".tmp"
    with open(tmp, "w") as f:
        json.dump(data, f, indent="\t")
    os.replace(tmp, src)
    names = ("red", "green", "yellow", "blue", "magenta", "cyan")
    moves = ["color%d->%s" % (idx + 1, names[slot])
             for slot, idx in enumerate(perm) if slot != idx]
    print("pywal-normalize: reassigned %s" % ", ".join(moves))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
