#!/usr/bin/env python3
# Genera el esquema [pywal] de un tema de spicetify desde la paleta de pywal.
#
# Las paletas pywal de muchos fondos son grises (saturación ~0-20%), así que un
# acento "tal cual" no se aprecia. Aquí tomamos el TONO (hue) dominante del
# wallpaper y partimos de SU saturación real con un empujón fijo (+0.15, suelo
# 0.30 para que se vea en fondos grises y techo 0.55 para no llegar a neón):
# el acento cambia de color con cada fondo y mantiene el aire del tema
# original, sin fluorescencia.
#
# El color.ini de 'termspot' trae 19 esquemas propios (Fdeox, Synthwave...), así
# que NO se sobrescribe el fichero: se inserta/reemplaza solo el bloque [pywal]
# y el resto queda intacto (así 'git pull' del tema no pierde nada nuestro ni al
# revés, y puedes probar los esquemas de fábrica con `spicetify config
# color_scheme Fdeox`).
#
# Uso: spicetify-colors.py [ruta_color.ini]
#      (por defecto ~/.config/spicetify/Themes/termspot/color.ini)
import json, sys, os, re, colorsys, math

HOME = os.path.expanduser("~")
SRC  = os.path.join(HOME, ".cache/wal/colors.json")
OUT  = sys.argv[1] if len(sys.argv) > 1 else \
       os.path.join(HOME, ".config/spicetify/Themes/termspot/color.ini")

try:
    d = json.load(open(SRC))
except Exception as e:
    sys.stderr.write("no colors.json: %s\n" % e)
    sys.exit(1)

sp, c = d["special"], d["colors"]

def h2rgb(h): h = h.lstrip("#"); return tuple(int(h[i:i+2], 16) / 255 for i in (0, 2, 4))
def H(r, g, b): return "%02X%02X%02X" % (round(r*255), round(g*255), round(b*255))
def strip(x): return x.lstrip("#").upper()

cols = [c["color%d" % i] for i in range(16)]
sat  = lambda h: colorsys.rgb_to_hls(*h2rgb(h))[2]
hue_of = lambda h: colorsys.rgb_to_hls(*h2rgb(h))[0]
def circ(a, b):
    d = abs(a - b) % 1.0
    return min(d, 1.0 - d)
# Dominant hue = most saturated of the chromatic slots (skips black/gray
# slots 0,7,8,15). A tiny vivid detail can win here while having nothing to
# do with the wallpaper, so reject it when it sits over 90 degrees away from
# the candidates' circular mean and the runner-up agrees with the mean.
cands = cols[1:7] + cols[9:15]
ranked = sorted(cands, key=sat, reverse=True)
best = ranked[0]
mean = math.atan2(sum(math.sin(hue_of(h) * 2 * math.pi) for h in cands) / len(cands),
                  sum(math.cos(hue_of(h) * 2 * math.pi) for h in cands) / len(cands)) / (2 * math.pi) % 1.0
if len(ranked) > 1 and circ(hue_of(best), mean) > 0.25 and circ(hue_of(ranked[1]), mean) <= 0.25:
    best = ranked[1]
best_hls = colorsys.rgb_to_hls(*h2rgb(best))
hue, s_best = best_hls[0], best_hls[2]
# Acento adaptativo: saturación real del fondo + empujón, con suelo (visible
# en grises) y techo (nunca neón). El tinte de superficies acompaña con el
# mismo criterio en vez de un 0.24 fijo.
acc_sat  = min(max(s_best + 0.15, 0.30), 0.55)
tint_sat = min(s_best + 0.08, 0.24)

mk   = lambda l, s: H(*colorsys.hls_to_rgb(hue, l, s))
bl   = colorsys.rgb_to_hls(*h2rgb(sp["background"]))[1]
# Superficies: oscuras pero CON tono, que es lo que da el aire de fósforo. La
# rampa (0.06 / 0.12 / 0.26 sobre el fondo) replica la separación del esquema
# Fdeox de termspot, medida sobre sus propios valores.
tint = lambda l: mk(min(l, 0.30), tint_sat)

accent  = mk(0.62, acc_sat)   # play / activo / barra / seleccionado
accent2 = mk(0.72, acc_sat)   # hover

body = f"""text               = {strip(sp['foreground'])}
subtext            = {strip(c['color8'])}
main               = {strip(sp['background'])}
accent             = {accent}
accent-active      = {accent2}
accent-inactive    = {strip(sp['background'])}
banner             = {accent}
border-active      = {accent}
border-inactive    = {tint(bl + 0.12)}
header             = {tint(bl + 0.26)}
highlight          = {tint(bl + 0.06)}
notification       = {accent}
notification-error = FF5C57
"""

section = "[pywal]\n; generado por spicetify-colors.py desde ~/.cache/wal/colors.json — no editar a mano\n" + body

os.makedirs(os.path.dirname(OUT), exist_ok=True)
old = open(OUT).read() if os.path.exists(OUT) else ""

# Reemplaza el bloque [pywal] existente (hasta el siguiente [seccion] o EOF).
# Si no lo hay, lo añade al final dejando los esquemas del tema intactos.
pat = re.compile(r"^\[pywal\][^\[]*", re.MULTILINE)
new = pat.sub(section, old, count=1) if pat.search(old) else \
      (old.rstrip("\n") + "\n\n" + section if old.strip() else section)

open(OUT, "w").write(new)
