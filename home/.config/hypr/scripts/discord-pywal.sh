#!/usr/bin/env bash
# Generates Discord (Vencord/Vesktop) QuickCSS from the pywal palette.
#
# Discord has no native theming: a client mod is required. This script writes
# CSS; Vencord watches quickCSS.css and applies it live without restarting. If
# Vencord is not installed yet, it prepares the file and exits successfully.
J="$HOME/.cache/wal/colors.json"
[ -f "$J" ] || exit 0

# Vencord-family directories. Vesktop always exists as the installed client;
# the theme is ready on first launch. Others are included only when present, so
# wallpaper changes do not recreate directories for uninstalled clients.
DIRS=("$HOME/.config/vesktop")
for d in "$HOME/.config/Vencord" "$HOME/.config/equibop" "$HOME/.config/VencordDesktop"; do
  [ -d "$d" ] && DIRS+=("$d")
done

CSS=$(python3 - "$J" <<'PY'
import colorsys, json, sys, math

c = json.load(open(sys.argv[1]))
pal, sp = c["colors"], c["special"]
bg, fg = sp["background"], sp["foreground"]


def hls(h):
    h = h.lstrip("#")
    r, g, b = (int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
    return colorsys.rgb_to_hls(r, g, b)


def hexof(h, l, s):
    r, g, b = colorsys.hls_to_rgb(h % 1.0, min(max(l, 0), 1), min(max(s, 0), 1))
    return "#%02x%02x%02x" % (round(r * 255), round(g * 255), round(b * 255))


bh, bl, bs = hls(bg)
dark = bl < 0.5
# Accent = the most saturated colorN (as in btop-pywal.sh), with adaptive
# saturation: wallpaper value plus a boost, floor for grays, and a 0.50 cap.
# As in Spicetify, reject a winner over 90 degrees from the circular mean when
# the runner-up represents it.
cands = [hls(pal[f"color{i}"]) for i in range(1, 7)]
ranked = sorted(cands, key=lambda t: t[2], reverse=True)
ah, al, as_ = ranked[0]
mean = math.atan2(sum(math.sin(t[0] * 2 * math.pi) for t in cands) / len(cands),
                  sum(math.cos(t[0] * 2 * math.pi) for t in cands) / len(cands)) / (2 * math.pi) % 1.0
def circ(a, b):
    d = abs(a - b) % 1.0
    return min(d, 1.0 - d)
if len(ranked) > 1 and circ(ah, mean) > 0.25 and circ(ranked[1][0], mean) <= 0.25:
    ah, al, as_ = ranked[1]
if as_ < 0.08:
    ah, al, as_ = hls(fg)
s_acc = min(max(as_, 0.15) + 0.10, 0.50)

step = 0.035 if dark else -0.035
# Background tiering: Discord uses multiple depth levels.
tiers = {
    "deepest": hexof(bh, max(bl - step, 0), bs),
    "tertiary": hexof(bh, max(bl - step * 0.5, 0), bs),
    "primary": bg,
    "secondary": hexof(bh, bl + step, bs),
    "floating": hexof(bh, bl + step * 1.6, bs),
    "hover": hexof(bh, bl + step * 2.2, bs),
}
def _lin(x):
    return x / 12.92 if x <= 0.03928 else ((x + 0.055) / 1.055) ** 2.4


def lum(h):
    h = h.lstrip("#")
    r, g, b = (_lin(int(h[i:i + 2], 16) / 255) for i in (0, 2, 4))
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def ratio(a, b):
    la, lb = sorted((lum(a), lum(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)


def readable(col, target):
    """Lighten (or darken) until the color is readable on the background."""
    h, l, s = hls(col)
    for _ in range(60):
        if ratio(hexof(h, l, s), bg) >= target:
            break
        l = min(l + 0.02, 1.0) if dark else max(l - 0.02, 0.0)
    return hexof(h, l, s)


accent = readable(hexof(ah, 0.55 if dark else 0.45, s_acc), 3.0)
accent_hi = readable(hexof(ah, 0.65 if dark else 0.38, s_acc), 4.5)
# Channel names and timestamps use this color; 4.0 provides readability margin.
muted = readable(hexof(bh, bl + (0.35 if dark else -0.35), bs * 0.6), 4.0)

v = {
    # --- backgrounds (legacy names) ---
    "--background-primary": tiers["primary"],
    "--background-secondary": tiers["secondary"],
    "--background-secondary-alt": tiers["tertiary"],
    "--background-tertiary": tiers["tertiary"],
    "--background-floating": tiers["floating"],
    "--background-accent": accent,
    "--background-modifier-hover": tiers["hover"],
    "--background-modifier-selected": tiers["hover"],
    "--background-modifier-accent": tiers["floating"],
    "--channeltextarea-background": tiers["secondary"],
    "--activity-card-background": tiers["floating"],
    # --- backgrounds (new names, Discord 2024+) ---
    "--bg-base-primary": tiers["primary"],
    "--bg-base-secondary": tiers["secondary"],
    "--bg-base-tertiary": tiers["tertiary"],
    "--bg-surface-overlay": tiers["floating"],
    "--bg-surface-raised": tiers["secondary"],
    # --- text ---
    "--text-normal": fg,
    "--text-default": fg,
    "--text-muted": muted,
    "--text-secondary": muted,
    "--text-link": accent_hi,
    "--header-primary": fg,
    "--header-secondary": muted,
    "--channels-default": muted,
    "--interactive-normal": muted,
    "--interactive-hover": fg,
    "--interactive-active": fg,
    "--interactive-muted": hexof(bh, bl + (0.18 if dark else -0.18), bs * 0.5),
    # --- accent / brand ---
    "--brand-experiment": accent,
    "--brand-500": accent,
    "--brand-560": accent_hi,
    "--button-filled-brand-background": accent,
    "--control-brand-foreground": accent_hi,
    "--scrollbar-thin-thumb": accent,
    "--scrollbar-auto-thumb": accent,
    "--scrollbar-auto-track": tiers["primary"],
}

print("/* generated by discord-pywal.sh (automatic; do not edit) */")
print(":root, .theme-dark, .theme-light {")
for k, val in v.items():
    print(f"  {k}: {val} !important;")
print("}")
PY
) || exit 0

# Do not publish without the key variables: the prior theme is better than a broken one.
case "$CSS" in
  *--background-primary*--brand-experiment*) : ;;
  *) exit 0 ;;
esac

for d in "${DIRS[@]}"; do
  mkdir -p "$d/settings" || continue
  TMP=$(mktemp "$d/settings/quickCSS.css.tmp.XXXXXX") || continue
  printf '%s\n' "$CSS" > "$TMP" && mv "$TMP" "$d/settings/quickCSS.css" || rm -f "$TMP"

  # QuickCSS must be enabled or the file is ignored. Change only this key,
  # preserving the user's remaining settings.
  S="$d/settings/settings.json"
  [ -f "$S" ] || printf '{}\n' > "$S"
  if command -v jq >/dev/null 2>&1; then
    TMP=$(mktemp "$S.tmp.XXXXXX") || continue
    jq '.useQuickCss = true' "$S" > "$TMP" 2>/dev/null && mv "$TMP" "$S" || rm -f "$TMP"
  fi
done
exit 0
