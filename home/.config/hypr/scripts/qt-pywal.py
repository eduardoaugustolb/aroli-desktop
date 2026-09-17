#!/usr/bin/env python3
"""Generates the Qt application palette from the pywal palette.

The desktop uses QT_QPA_PLATFORMTHEME=qt6ct (see environment.d), and VLC
-the only Qt5 app- uses qt5ct through the ~/.local/bin/vlc wrapper. Both
platform themes read their palette from a file, and this script writes that
file.

Previously, the desktop used the gtk3 theme and this was only needed for Qt5.
The reason for changing: with gtk3, Qt6 did inherit colors (its qgtk3 plugin
reads real GTK widgets), but only when opening a window, so already-open
windows kept the old palette until restarted. Qt5 never inherited them: its
qgtk3 provides dialogs, fonts, and hints, never colors -tested with a minimal
Qt5 binary, with and without gtk3 gave the same result-, which made VLC white
(#efefef on #ffffff) in the middle of a pywal desktop.

There are three outputs:

   1. The qt5ct scheme (~/.config/qt5ct/colors/pywal.conf), for VLC.
   2. The qt6ct scheme, for the rest of the Qt desktop.
   3. The color sections in ~/.config/kdeglobals, which KDE Frameworks apps
      read when they request colors independently (KColorScheme). It had a
      static lilac 'MaterialYouDark' scheme inherited from old metapackages,
      unrelated to the wallpaper.

Each of the two *ct configurations is only written if it is installed; if it
is missing, no unused files are created.
"""

import colorsys
import json
import os
import re
import shutil
import sys
from datetime import date

CACHE = os.path.expanduser("~/.cache/wal/colors.json")
CONFIG = os.path.expanduser("~/.config")
BACKUPS = os.path.expanduser(f"~/.config-rice-backups/{date.today().isoformat()}")


# --- color utilities ---------------------------------------------------------

def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


def hexa(t):
    return "#" + "".join(f"{max(0, min(255, round(c * 255))):02x}" for c in t)


def lum(h):
    """Relative luminance (WCAG), used for light/dark decisions and contrast."""
    def lin(c):
        return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = rgb(h)
    return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)


def contrast(a, b):
    la, lb = lum(a), lum(b)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)


def shade(h, amount):
    """Lightens (amount>0) or darkens (amount<0) by changing HLS L.

    This is done in HLS rather than mixing with white/black to avoid washing
    out the tint: pywal backgrounds are usually near-black with an image tint,
    which is what makes the window feel like part of the desktop.
    """
    r, g, b = rgb(h)
    hh, ll, ss = colorsys.rgb_to_hls(r, g, b)
    ll = max(0.0, min(1.0, ll + amount))
    return hexa(colorsys.hls_to_rgb(hh, ll, ss))


def mix(a, b, t):
    """Linear blend: t=0 returns a, t=1 returns b."""
    ra, ga, ba = rgb(a)
    rb, gb, bb = rgb(b)
    return hexa((ra + (rb - ra) * t, ga + (gb - ga) * t, ba + (bb - ba) * t))


def legible(fondo, *candidatos):
    """The candidate with the highest contrast against 'fondo'."""
    return max(candidatos, key=lambda c: contrast(fondo, c))


def semantico(base, fondo, tono, sat_min=0.45):
    """A semantic color (error, success, warning) tinted by the palette.

    The three semantic colors cannot come directly from pywal: with a blue
    wallpaper, color1 is blue and a blue error message signals nothing. The
    palette's lightness and saturation are retained, but the hue is forced to
    one people already understand and lightness is raised until readable.
    """
    r, g, b = rgb(base)
    _, ll, ss = colorsys.rgb_to_hls(r, g, b)
    ss = max(ss, sat_min)
    ll = min(max(ll, 0.45), 0.75) if lum(fondo) < 0.5 else min(max(ll, 0.30), 0.50)
    color = hexa(colorsys.hls_to_rgb(tono, ll, ss))
    paso = 0.04 if lum(fondo) < 0.5 else -0.04
    while contrast(fondo, color) < 3.5 and 0.05 < ll < 0.95:
        ll += paso
        color = hexa(colorsys.hls_to_rgb(tono, ll, ss))
    return color


# --- palette -----------------------------------------------------------------

def construir(wal):
    c = wal["colors"]
    esp = wal["special"]
    bg, fg = esp["background"], esp["foreground"]
    accent = c["color4"]
    oscuro = lum(bg) < 0.5
    # Surface direction: on a dark background, surfaces rise; on a light one,
    # they recede. Without this, a light wallpaper would make buttons invisible.
    s = 1 if oscuro else -1

    p = {}
    p["window"] = bg
    p["windowtext"] = fg
    # Views (lists and text boxes) recede slightly relative to the window;
    # buttons rise. This is the same surface treatment used by Fusion.
    p["base"] = shade(bg, -0.030 * s)
    p["alternatebase"] = shade(bg, 0.035 * s)
    p["text"] = fg
    p["button"] = shade(bg, 0.055 * s)
    p["buttontext"] = fg
    p["brighttext"] = c["color15"]
    p["light"] = shade(p["button"], 0.10 * s)
    p["midlight"] = shade(p["button"], 0.05 * s)
    p["mid"] = shade(p["button"], -0.05 * s)
    p["dark"] = shade(p["button"], -0.10 * s)
    p["shadow"] = shade(bg, -0.06 * s)
    p["highlight"] = accent
    # Selected text is chosen by measured contrast, not by eye: with dark
    # accents (night blue), the pywal background on top was unreadable.
    p["highlightedtext"] = legible(accent, bg, fg, c["color15"], c["color0"])
    if contrast(accent, p["highlightedtext"]) < 4.5:
        # If the palette has no readable color over the accent, use white or
        # black: an unreadable selection is worse than an external color.
        p["highlightedtext"] = legible(accent, "#ffffff", "#000000")
    p["link"] = c["color6"] if contrast(bg, c["color6"]) >= 3.5 else shade(accent, 0.15 * s)
    p["linkvisited"] = c["color5"] if contrast(bg, c["color5"]) >= 3.5 else shade(c["color5"], 0.15 * s)
    p["tooltipbase"] = shade(bg, 0.08 * s)
    p["tooltiptext"] = fg
    p["placeholder"] = mix(fg, bg, 0.55)
    p["accent"] = accent
    # Disabled: not an arbitrary gray, but the text itself moved toward the
    # background, which reads as "dimmed" rather than "broken".
    p["disabledtext"] = mix(fg, bg, 0.62)
    p["border"] = shade(bg, 0.14 * s)
    return p


# --- output 1: qt5ct / qt6ct color scheme -----------------------------------

# QPalette::ColorRole order as serialized by qt5ct/qt6ct: a comma-separated
# color list by role index. All three groups (active, disabled, inactive) use
# the complete list.
ROLES = [
    "windowtext", "button", "light", "midlight", "dark", "mid", "text",
    "brighttext", "buttontext", "base", "window", "shadow", "highlight",
    "highlightedtext", "link", "linkvisited", "alternatebase", "norole",
    "tooltipbase", "tooltiptext", "placeholder", "accent",
]


def lista_colores(p, grupo):
    fuera = []
    for rol in ROLES:
        if rol == "norole":
            fuera.append(p["window"])
            continue
        v = p[rol]
        if grupo == "disabled" and rol in ("windowtext", "text", "buttontext", "brighttext"):
            v = p["disabledtext"]
        if grupo == "disabled" and rol == "highlight":
            v = p["button"]
        if grupo == "inactive" and rol == "highlight":
            v = mix(p["highlight"], p["window"], 0.35)
        fuera.append(v)
    # qt5ct/qt6ct expect #AARRGGBB
    return ", ".join("#ff" + v.lstrip("#").lower() for v in fuera)


def escribir_esquema(p, destino):
    os.makedirs(os.path.dirname(destino), exist_ok=True)
    texto = (
        "[ColorScheme]\n"
        "; generated by qt-pywal.py from ~/.cache/wal/colors.json\n"
        "; rewritten on every wallpaper change: do not edit manually\n"
        f"active_colors={lista_colores(p, 'active')}\n"
        f"disabled_colors={lista_colores(p, 'disabled')}\n"
        f"inactive_colors={lista_colores(p, 'inactive')}\n"
    )
    escribir_en_sitio(destino, texto)


def asegurar_conf_ct(carpeta, esquema):
    """Points qt5ct.conf/qt6ct.conf to the scheme without overwriting the rest.

    If the user has never opened qt5ct, the file does not exist and is created
    with the minimum configuration. If it exists, only keys needed to apply the
    palette are touched.
    """
    nombre = os.path.basename(carpeta)
    conf = os.path.join(carpeta, f"{nombre}.conf")
    claves = {
        "color_scheme_path": esquema,
        "custom_palette": "true",
        "style": "Fusion",
        "icon_theme": primer_tema_de_iconos(),
    }
    if not os.path.exists(conf):
        os.makedirs(carpeta, exist_ok=True)
        cuerpo = "[Appearance]\n" + "".join(f"{k}={v}\n" for k, v in claves.items())
        # File dialogs remain GTK dialogs: that is what the rest of the desktop
        # uses and the only gtk3 theme component worth keeping with qt6ct.
        cuerpo += "standard_dialogs=gtk3\n"
        escribir_en_sitio(conf, cuerpo)
        return

    with open(conf, encoding="utf-8") as f:
        lineas = f.read().splitlines()
    salida, en_appearance, puestas = [], False, set()
    for linea in lineas:
        if linea.startswith("["):
            if en_appearance:
                # After the section's last key, not after the blank line that
                # separates it from the next section.
                while salida and not salida[-1].strip():
                    salida.pop()
                for k, v in claves.items():
                    if k not in puestas:
                        salida.append(f"{k}={v}")
                        puestas.add(k)
                salida.append("")
            en_appearance = linea.strip() == "[Appearance]"
        elif en_appearance:
            m = re.match(r"\s*([A-Za-z_]+)\s*=", linea)
            if m and m.group(1) in claves:
                k = m.group(1)
                salida.append(f"{k}={claves[k]}")
                puestas.add(k)
                continue
        salida.append(linea)
    if en_appearance:
        for k, v in claves.items():
            if k not in puestas:
                salida.append(f"{k}={v}")
    elif "[Appearance]" not in "\n".join(salida):
        salida.append("[Appearance]")
        salida += [f"{k}={v}" for k, v in claves.items()]
    # The .conf is always touched LAST, even when unchanged: the platform theme
    # watches it, and this signals already-open applications to reload colors.
    escribir_en_sitio(conf, "\n".join(salida) + "\n")


# --- output 2: kdeglobals ----------------------------------------------------

def grupos_kde(p):
    """kdeglobals [Colors:*] and [WM] sections using the pywal palette."""
    comun = {
        "DecorationFocus": p["highlight"],
        "DecorationHover": p["highlight"],
        "ForegroundActive": p["windowtext"],
        "ForegroundInactive": p["disabledtext"],
        "ForegroundLink": p["link"],
        "ForegroundNegative": p["negative"],
        "ForegroundNeutral": p["neutral"],
        "ForegroundNormal": p["windowtext"],
        "ForegroundPositive": p["positive"],
        "ForegroundVisited": p["linkvisited"],
    }

    def bloque(normal, alterno, extra=None):
        d = dict(comun)
        d["BackgroundNormal"] = normal
        d["BackgroundAlternate"] = alterno
        if extra:
            d.update(extra)
        return dict(sorted(d.items()))

    return {
        "Colors:Button": bloque(p["button"], p["alternatebase"]),
        "Colors:Complementary": bloque(p["base"], p["alternatebase"]),
        "Colors:Header": bloque(p["window"], p["alternatebase"]),
        "Colors:Header][Inactive": bloque(p["base"], p["alternatebase"]),
        "Colors:Selection": bloque(
            p["highlight"], p["highlight"],
            {
                "ForegroundActive": p["highlightedtext"],
                "ForegroundInactive": p["highlightedtext"],
                "ForegroundNormal": p["highlightedtext"],
                "ForegroundLink": p["highlightedtext"],
                "ForegroundVisited": p["highlightedtext"],
            },
        ),
        "Colors:Tooltip": bloque(p["tooltipbase"], p["alternatebase"]),
        "Colors:View": bloque(p["base"], p["alternatebase"]),
        "Colors:Window": bloque(p["window"], p["alternatebase"]),
    }


def coma_rgb(h):
    return ",".join(str(round(c * 255)) for c in rgb(h))


ICONOS = [
    os.path.expanduser("~/.local/share/icons"),
    os.path.expanduser("~/.icons"),
    "/usr/share/icons",
]


def tema_de_iconos_existe(nombre):
    return any(os.path.isdir(os.path.join(d, nombre)) for d in ICONOS)


def primer_tema_de_iconos():
    """The icon theme for Qt apps: the same one used by GTK.

    It is read from GTK3's settings.ini instead of being set here so both
    halves of the desktop show the same icon. With breeze-dark, kdialog showed
    KDE's fixed blue circle where the rest of the desktop showed Adwaita's.
    """
    ini = os.path.join(CONFIG, "gtk-3.0", "settings.ini")
    try:
        with open(ini, encoding="utf-8") as f:
            m = re.search(r"^gtk-icon-theme-name\s*=\s*(.+)$", f.read(), re.M)
        if m and tema_de_iconos_existe(m.group(1).strip()):
            return m.group(1).strip()
    except OSError:
        pass
    for nombre in ("Adwaita", "breeze-dark", "breeze"):
        if tema_de_iconos_existe(nombre):
            return nombre
    return "hicolor"


def actualizar_kdeglobals(p):
    ruta = os.path.join(CONFIG, "kdeglobals")
    previo = []
    if os.path.exists(ruta):
        with open(ruta, encoding="utf-8") as f:
            previo = f.read().splitlines()
        respaldo(ruta)

    nuevas = grupos_kde(p)
    # Preserve everything non-color-related (fonts, KFileDialog, icons...) and
    # fully replace color sections to avoid mixing the old and new palettes.
    fuera, seccion, saltando = [], None, False
    generales, kde = {}, {}
    for linea in previo:
        if linea.startswith("["):
            seccion = linea.strip().strip("[]").replace("][", "][")
            nombre = linea.strip()[1:-1]
            saltando = (
                nombre in nuevas
                or nombre.startswith("Colors:")
                or nombre == "WM"
                or nombre.startswith("ColorEffects:")
            )
            if not saltando:
                fuera.append(linea)
            continue
        if saltando:
            continue
        if seccion == "General":
            m = re.match(r"(ColorScheme|ColorSchemeHash|LastUsedCustomAccentColor)\s*=", linea)
            if m:
                generales[m.group(1)] = True
                continue
        if seccion == "KDE":
            m = re.match(r"(widgetStyle)\s*=", linea)
            if m:
                kde[m.group(1)] = True
                continue
        if seccion == "Icons":
            # Always rewrite the icon theme using GTK's: it pointed to
            # 'breeze-plus-dark', removed with old metapackages, leaving KDE
            # apps without icons; breeze-dark showed KDE's fixed blue instead.
            if re.match(r"Theme\s*=", linea):
                continue
        fuera.append(linea)

    texto = "\n".join(fuera).strip("\n")

    def anadir_a_seccion(txt, nombre, pares):
        """Adds keys to an existing section or creates it at the end."""
        marca = f"[{nombre}]"
        if marca in txt:
            partes = txt.split(marca, 1)
            resto = partes[1].lstrip("\n")
            if resto.startswith("["):  # Empty section: keep sections separate.
                resto = "\n" + resto
            return partes[0] + marca + "\n" + "".join(f"{k}={v}\n" for k, v in pares.items()) + resto
        return txt + f"\n\n{marca}\n" + "".join(f"{k}={v}\n" for k, v in pares.items())

    texto = anadir_a_seccion(texto, "General", {"ColorScheme": "Pywal"})
    texto = anadir_a_seccion(texto, "Icons", {"Theme": primer_tema_de_iconos()})
    # The style pointed to uninstalled 'Darkly': KDE apps fell back to the
    # default style and its factory palette.
    texto = anadir_a_seccion(texto, "KDE", {"widgetStyle": "Fusion"})

    bloques = []
    for nombre, pares in nuevas.items():
        bloques.append(f"[{nombre}]\n" + "".join(f"{k}={v}\n" for k, v in pares.items()))
    # KDE effects for inactive/disabled windows retain their settings except
    # for the base color, which was lilac from the old scheme.
    bloques.append(
        "[ColorEffects:Disabled]\n"
        "Color=" + p["window"] + "\n"
        "ColorAmount=0.5\nColorEffect=3\nContrastAmount=0\nContrastEffect=0\n"
        "IntensityAmount=0\nIntensityEffect=0\n"
    )
    bloques.append(
        "[ColorEffects:Inactive]\n"
        "ChangeSelectionColor=true\n"
        "Color=" + p["base"] + "\n"
        "ColorAmount=0.025\nColorEffect=0\nContrastAmount=0.1\nContrastEffect=0\n"
        "Enable=true\nIntensityAmount=0\nIntensityEffect=0\n"
    )
    # [WM] contains window-frame colors; Hyprland decorates them here, but some
    # KDE apps use them for their own title bars.
    bloques.append(
        "[WM]\n"
        f"activeBackground={coma_rgb(p['window'])}\n"
        f"activeBlend={coma_rgb(p['highlight'])}\n"
        f"activeForeground={coma_rgb(p['windowtext'])}\n"
        f"inactiveBackground={coma_rgb(p['base'])}\n"
        f"inactiveBlend={coma_rgb(p['border'])}\n"
        f"inactiveForeground={coma_rgb(p['disabledtext'])}\n"
    )

    texto = texto.rstrip("\n") + "\n\n" + "\n".join(bloques)
    # Keep the same inode for two reasons: already-open KDE apps notice it, as
    # with qt5ct/qt6ct .conf files. Crucially, with install.sh --link,
    # ~/.config/kdeglobals is a repository symlink; temp + rename replaces that
    # link with a standalone file and silently disconnects the dotfile.
    escribir_en_sitio(ruta, texto)


# --- plumbing ----------------------------------------------------------------

def respaldo(ruta):
    os.makedirs(BACKUPS, exist_ok=True)
    destino = os.path.join(BACKUPS, os.path.basename(ruta) + ".pre-qt-pywal")
    if not os.path.exists(destino):
        shutil.copy2(ruta, destino)


def escribir_en_sitio(ruta, texto, modo=0o644):
    """Writes while preserving the inode instead of creating and renaming.

    This lets already-open Qt applications change color without restarting.
    qt5ct/qt6ct platform themes watch their configuration with
    QFileSystemWatcher, which follows the INODE: using the usual temporary file
    plus os.replace leaves the watch looking at a nonexistent file forever.
    Tested with VLC visible: atomic writes changed nothing; writing the same
    inode updated its color within three seconds.
    """
    with open(ruta, "w", encoding="utf-8") as f:
        f.write(texto)
        f.flush()
        os.fsync(f.fileno())
    os.chmod(ruta, modo)


def main():
    try:
        with open(CACHE, encoding="utf-8") as f:
            wal = json.load(f)
    except (OSError, ValueError) as e:
        print(f"qt-pywal: could not read {CACHE}: {e}", file=sys.stderr)
        return 1

    p = construir(wal)
    c = wal["colors"]
    bg = wal["special"]["background"]
    # Error in red, success in green, warning in amber: hue is fixed while
    # lightness and saturation come from the wallpaper palette.
    p["negative"] = semantico(c["color1"], bg, 0.00)
    p["positive"] = semantico(c["color2"], bg, 0.33)
    p["neutral"] = semantico(c["color3"], bg, 0.10)

    hechos = []
    for nombre in ("qt5ct", "qt6ct"):
        # Generate only for installed applications; otherwise their files would
        # be unused.
        if shutil.which(nombre) is None:
            continue
        carpeta = os.path.join(CONFIG, nombre)
        esquema = os.path.join(carpeta, "colors", "pywal.conf")
        escribir_esquema(p, esquema)
        asegurar_conf_ct(carpeta, esquema)
        hechos.append(nombre)

    actualizar_kdeglobals(p)
    hechos.append("kdeglobals")
    print("qt-pywal: " + ", ".join(hechos))
    return 0


if __name__ == "__main__":
    sys.exit(main())
