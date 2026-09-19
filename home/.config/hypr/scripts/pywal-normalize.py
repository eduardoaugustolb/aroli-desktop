#!/usr/bin/env python3
# pywal-normalize.py — reassigns pywal's chromatic slots by hue and applies
# the selected surface intensity.
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

# Umbra's stable dark foundation. Wallpaper colour belongs in the accents, not
# in the surface below every application. These four ANSI slots are the neutral
# tiers pywal normally derives from the dominant image area.
UMBRA_SPECIAL = {"background": "#0d0f12", "foreground": "#e7eaf0"}
UMBRA_SURFACE_SLOTS = {
    "color0": "#16191f", "color7": "#cbd1dc",
    "color8": "#68707d", "color15": "#f5f7fb",
}


def rice_settings():
    """Return the persisted palette settings without making the shell a dependency."""
    config = os.path.join(os.path.expanduser("~"), ".config", "quickshell-rice.json")
    try:
        with open(config) as f:
            return json.load(f)
    except Exception:
        return {}


def surface_intensity(settings):
    """Read the user's 0..4 wallpaper-surface intensity.

    paletteMode predates the slider. Its values deliberately map to the old
    endpoints so upgrading changes no one's desktop: ``umbra`` is 0 and
    ``wallpaper`` is 4.
    """
    try:
        if "paletteIntensity" not in settings:
            return 4 if settings.get("paletteMode") == "wallpaper" else 0
        return max(0, min(4, int(settings["paletteIntensity"])))
    except Exception:
        return 0


def blend_hex(stable, wallpaper, amount):
    """Mix two #rrggbb colours. amount is 0.0 (stable) through 1.0 (raw)."""
    def channels(value):
        value = value.lstrip("#")
        return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))

    a, b = channels(stable), channels(wallpaper)
    return "#%02x%02x%02x" % tuple(round(x + (y - x) * amount)
                                     for x, y in zip(a, b))


def valid_hex(value):
    return isinstance(value, str) and len(value) == 7 and value.startswith("#") and \
        all(c in "0123456789abcdefABCDEF" for c in value[1:])


def luminance(value):
    rgb = [int(value[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    rgb = [x / 12.92 if x <= .03928 else ((x + .055) / 1.055) ** 2.4 for x in rgb]
    return .2126 * rgb[0] + .7152 * rgb[1] + .0722 * rgb[2]


def contrast(a, b):
    return (max(luminance(a), luminance(b)) + .05) / (min(luminance(a), luminance(b)) + .05)


def readable(foreground, background, minimum):
    """Keep the hue but move lightness until text has the requested contrast."""
    h, l, s = hls(foreground)
    toward_light = luminance(background) < .5
    for _ in range(100):
        candidate = "#%02x%02x%02x" % tuple(round(x * 255) for x in colorsys.hls_to_rgb(h, l, s))
        if contrast(candidate, background) >= minimum:
            return candidate
        l = min(1, l + .01) if toward_light else max(0, l - .01)
    return "#ffffff" if toward_light else "#000000"


def saturate(value, amount):
    h, l, s = hls(value)
    s = min(1, max(0, s * amount))
    return "#%02x%02x%02x" % tuple(round(x * 255) for x in colorsys.hls_to_rgb(h, l, s))


def apply_surface(data, intensity, settings):
    """Keep a raw pywal snapshot, then blend stable and wallpaper surfaces.

    The snapshot makes switching intensity reversible without extracting the
    image again. Accent slots (color1..6 and color9..14) deliberately stay
    dynamic. The stops give the middle of the slider more room than a linear
    0..4 mapping: each is visibly distinct without making level 1 noisy.
    """
    meta = data.setdefault("umbra", {})
    colors, special = data["colors"], data["special"]
    if "wallpaper_special" not in meta:
        meta["wallpaper_special"] = {
            "background": special.get("background"),
            "foreground": special.get("foreground"),
        }
    if "wallpaper_surface_slots" not in meta:
        meta["wallpaper_surface_slots"] = {
            slot: colors.get(slot) for slot in UMBRA_SURFACE_SLOTS
        }

    preset = settings.get("palettePreset", "hybrid")
    if preset == "wallpaper":
        intensity = 4
    elif preset in ("umbra", "manual"):
        intensity = 0
    amount = (0.0, 0.18, 0.42, 0.72, 1.0)[intensity]
    for key, stable in UMBRA_SPECIAL.items():
        raw = meta["wallpaper_special"].get(key)
        if raw:
            special[key] = blend_hex(stable, raw, amount)
    for key, stable in UMBRA_SURFACE_SLOTS.items():
        raw = meta["wallpaper_surface_slots"].get(key)
        if raw:
            colors[key] = blend_hex(stable, raw, amount)
    if preset == "manual":
        manual = {
            "background": settings.get("paletteCanvas"),
            "foreground": settings.get("paletteText"),
        }
        slots = {"color0": settings.get("paletteSurface"), "color7": settings.get("paletteText")}
        special.update({key: value for key, value in manual.items() if valid_hex(value)})
        colors.update({key: value for key, value in slots.items() if valid_hex(value)})
        if valid_hex(settings.get("paletteAccent")):
            colors["color4"] = settings["paletteAccent"]

    saturation = max(0, min(200, int(settings.get("paletteSaturation", 100)))) / 100
    for index in list(range(1, 7)) + list(range(9, 15)):
        colors["color%d" % index] = saturate(colors["color%d" % index], saturation)

    if settings.get("paletteSemanticMode") == "fixed":
        colors.update({"color1": "#c78995", "color2": "#83b89a", "color3": "#cda27c",
                       "color5": "#9d7fd1", "color6": "#00a6c7"})
    minimum = max(3.0, min(7.0, float(settings.get("paletteMinContrast", 4.5))))
    special["foreground"] = readable(special["foreground"], special["background"], minimum)
    meta["surface_intensity"] = intensity
    meta["palette_preset"] = preset


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
    if changed:
        for slot, idx in enumerate(perm):
            data["colors"]["color%d" % (slot + 1)] = group[idx]
            data["colors"]["color%d" % (slot + 9)] = brights[idx]
    settings = rice_settings()
    intensity = surface_intensity(settings)
    apply_surface(data, intensity, settings)
    tmp = src + ".tmp"
    with open(tmp, "w") as f:
        json.dump(data, f, indent="\t")
    os.replace(tmp, src)
    names = ("red", "green", "yellow", "blue", "magenta", "cyan")
    moves = ["color%d->%s" % (idx + 1, names[slot])
             for slot, idx in enumerate(perm) if slot != idx]
    detail = ", ".join(moves) if moves else "slots already hue-aligned"
    print("pywal-normalize: %s; surface-intensity=%s" % (detail, data["umbra"]["surface_intensity"]))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
