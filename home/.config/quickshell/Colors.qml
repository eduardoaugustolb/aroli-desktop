pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Reads the pywal palette (~/.cache/wal/colors.json) and refreshes live
// every time you switch wallpaper (set-wallpaper.sh regenerates that file).
Singleton {
    id: root

    // Fallbacks (gruvbox-ish) in case no pywal has been generated yet
    property color bg:      "#1d2021"
    property color bgAlt:   "#282828"
    property color fg:      "#ebdbb2"
    property color accent:  "#61afef"
    property color accent2: "#fe8019"
    property color dim:     "#928374"
    property color c1: "#fb4934"
    property color c2: "#b8bb26"
    property color c3: "#fabd2f"
    property color c4: "#83a598"
    property color c5: "#d3869b"

    // SEMANTIC colors: fixed on purpose. c1..c5 come from pywal and change with
    // the wallpaper (color2 does not have to be green), so they cannot say
    // "charging" or "critical" — with some wallpapers the charging battery came
    // out red and looked like an alarm.
    readonly property color ok:   "#6dbd7a"
    readonly property color warn: "#e0a458"
    readonly property color crit: "#e05c5c"

    // Current wallpaper path. Lives here and not in Config because pywal
    // is in charge: colors.json carries the path of the wallpaper the palette
    // came from, so color and wallpaper can NEVER desync. Storing it separately
    // in the rice JSON would mean two sources of truth for the same thing.
    // The overview uses it to paint each workspace.
    property string wallpaper: ""

    // ══════════════════════════════════════════════════════════════════════
    //  INK FOR WHAT FLOATS OVER THE WALLPAPER
    //
    //  The bar has no surface of its own —the veil defaults to 0—, so
    //  its bodies paint DIRECTLY onto the wallpaper. And since
    //  pywal derives the palette from that same wallpaper, on a monochrome
    //  background the accent comes back tinted the same hue as the background
    //  with similar lightness: it re-themes fine and still cannot be seen.
    //
    //  Measured on the workspace indicator with a blue wallpaper: the active
    //  pill (#366ca3) sat at 1.6:1 against the inactive dots, and the dots
    //  —white at 50%— were the BRIGHTEST thing in the group. That is, the dim
    //  stood out more than the lit, and on top the pill came out darker
    //  than chunks of the wallpaper itself.
    //
    //  Measured against `wallStrip`, which is a REAL slice of the wallpaper
    //  (see below), not against the pywal background. And resolved like this:
    //    · active   → 3.5:1 against the strip. Above the 3:1 a graphic
    //      element asks for, because it IS the indicator.
    //    · inactive → right at the MIDPOINT between the strip and the active,
    //      that is at the root of this contrast (~1.9:1 per side). A midpoint
    //      can blend neither into the background nor into the pill, which are
    //      the two ways to get lost; and since it derives from the pill, the
    //      hierarchy holds on its own with no hand-tuned numbers.
    //
    //  Only LIGHTNESS moves: the hue stays pywal's, so re-theming is fully kept.
    // ══════════════════════════════════════════════════════════════════════
    readonly property bool darkWall: wallStrip.hslLightness < 0.5

    readonly property color onWallAccent: {
        const h = accent.hslHue < 0 ? 0 : accent.hslHue;
        // A gray accent is gray: forcing saturation onto it would invent a hue
        // (with an achromatic palette the indicator came out red from nowhere).
        const s = accent.hslSaturation < 0.08
            ? accent.hslSaturation : Math.max(accent.hslSaturation, 0.6);
        let l = accent.hslLightness;
        let out = Qt.hsla(h, s, l, 1);
        for (let i = 0; i < 60 && contrast(out, wallStrip) < 3.5; i++) {
            l = darkWall ? Math.min(l + 0.02, 1) : Math.max(l - 0.02, 0);
            out = Qt.hsla(h, s, l, 1);
        }
        return out;
    }

    // OPAQUE on purpose. With translucent ink the wallpaper ended up
    // setting the final color: the same dots measured 0.19 or 0.31 luminance
    // depending on which background chunk sat behind them, so over a light
    // area they blended back into it. An opaque body is computed once and
    // always holds.
    readonly property color onWallDim: {
        const h = accent.hslHue < 0 ? 0 : accent.hslHue;
        const target = Math.sqrt(contrast(onWallAccent, wallStrip));
        let l = wallStrip.hslLightness;
        let out = Qt.hsla(h, 0.12, l, 1);
        for (let i = 0; i < 60 && contrast(out, wallStrip) < target; i++) {
            l = darkWall ? Math.min(l + 0.02, 1) : Math.max(l - 0.02, 0);
            out = Qt.hsla(h, 0.12, l, 1);
        }
        return out;
    }

    // The REAL color of the wallpaper's top strip, which is what sits
    // BEHIND the bar bodies. set-wallpaper.sh samples it with
    // magick; if that file is missing (or magick failed) this stays on the
    // pywal background, which is what there was before.
    property color wallStrip: bg
    FileView {
        id: stripFile
        path: Quickshell.env("HOME") + "/.cache/wal/bar-strip.txt"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const t = stripFile.text().trim();
            if (/^#[0-9a-fA-F]{6}$/.test(t)) root.wallStrip = t;
        }
    }

    function _lin(x) { return x <= 0.03928 ? x / 12.92 : Math.pow((x + 0.055) / 1.055, 2.4); }
    function luminance(c) { return 0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b); }
    // WCAG contrast between two opaque colors, 1:1 (equal) to 21:1 (black/white).
    function contrast(a, b) {
        const x = luminance(a), y = luminance(b);
        return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05);
    }

    function _c(hex, fb) { return (hex && String(hex).length > 0) ? hex : fb }

    FileView {
        id: wal
        path: Quickshell.env("HOME") + "/.cache/wal/colors.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.apply()
    }

    function apply() {
        var t = wal.text();
        if (!t || t.length === 0) return;
        try {
            var j = JSON.parse(t);
            var s = j.special, c = j.colors;
            // Wallpaper ownership and palette ownership are separate: a user
            // may keep the image changing while freezing shell colours.
            if (j.wallpaper && String(j.wallpaper).length > 0)
                root.wallpaper = "file://" + j.wallpaper;
            if (!Config.paletteScopeShell) return;
            root.bg      = _c(s.background, root.bg);
            root.fg      = _c(s.foreground, root.fg);
            root.bgAlt   = _c(c.color0,  root.bgAlt);
            root.accent  = _c(c.color4,  root.accent);
            root.accent2 = _c(c.color1,  root.accent2);
            root.dim     = _c(c.color8,  root.dim);
            root.c1 = _c(c.color1, root.c1);
            root.c2 = _c(c.color2, root.c2);
            root.c3 = _c(c.color3, root.c3);
            root.c4 = _c(c.color4, root.c4);
            root.c5 = _c(c.color5, root.c5);
        } catch (e) { /* keeps fallbacks */ }
    }
}
