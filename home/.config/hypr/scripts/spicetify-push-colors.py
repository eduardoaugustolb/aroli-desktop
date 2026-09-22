#!/usr/bin/env python3
# Pushes the pywal palette to an ALREADY OPEN Spotify window, live.
#
# Why this exists: 'spicetify apply' rebuilds on disk but does not touch open
# Spotify, while 'spicetify watch' fully reloads xpui (1-2 s flash and lost
# scroll). The Spicetify maintainer acknowledges this often fails on Linux:
# DevTools websocket [...] On Linux it mostly fails").
#
# Instead, use the DevTools WebSocket directly and rewrite only --spice-* CSS
# variables. Repainting is immediate, preserving scroll and UI state.
#
# Requires Spotify to be launched with --remote-debugging-port (set by the
# ~/.local/share/applications/spotify.desktop override).
#
# Exit status: 0 if colors were applied; nonzero if not (Spotify closed, no port,
# and so on), allowing the caller to decide whether a restart is needed.
#
# Usage: spicetify-push-colors.py [color.ini path] [--port N] [--section pywal]
import base64, json, os, re, socket, struct, sys, urllib.request

PUERTO = 9333
SECCION = "pywal"
INI = os.path.expanduser("~/.config/spicetify/Themes/aroli/color.ini")

args = sys.argv[1:]
i = 0
posicional = []
while i < len(args):
    if args[i] == "--puerto":
        PUERTO = int(args[i + 1]); i += 2
    elif args[i] == "--seccion":
        SECCION = args[i + 1]; i += 2
    else:
        posicional.append(args[i]); i += 1
if posicional:
    INI = posicional[0]


def morir(msg, codigo=1):
    sys.stderr.write("spicetify-push-colors: %s\n" % msg)
    sys.exit(codigo)


# ---- 1. read the color.ini section ------------------------------------------
# Parse manually rather than using configparser: the theme color.ini has
# several sections and ';' comments, while only one section is needed.
def leer_seccion(ruta, seccion):
    try:
        texto = open(ruta).read()
    except OSError as e:
        morir("cannot read %s: %s" % (ruta, e))
    m = re.search(r"^\[%s\][^\[]*" % re.escape(seccion), texto, re.M)
    if not m:
        morir("section [%s] is missing from %s" % (seccion, ruta))
    colores = {}
    for linea in m.group(0).splitlines()[1:]:
        linea = linea.strip()
        if not linea or linea.startswith(";") or "=" not in linea:
            continue
        k, _, v = linea.partition("=")
        v = v.strip().lstrip("#").upper()
        if re.fullmatch(r"[0-9A-F]{6}", v):
            colores[k.strip()] = v
    if not colores:
        morir("section [%s] has no valid colors" % seccion)
    return colores


# ---- 2. minimal WebSocket client (RFC 6455) ---------------------------------
# No websocat or websockets module is installed; a dependency is unnecessary
# for four messages. Client frames are always masked; server frames are not.
class WS:
    def __init__(self, url, origin, timeout=4):
        if not url.startswith("ws://"):
            raise ValueError("URL is not ws://: %s" % url)
        hostport, _, path = url[5:].partition("/")
        host, _, puerto = hostport.partition(":")
        self.s = socket.create_connection((host, int(puerto or 80)), timeout=timeout)
        self.s.settimeout(timeout)
        clave = base64.b64encode(os.urandom(16)).decode()
        self.s.sendall(
            (
                "GET /%s HTTP/1.1\r\n"
                "Host: %s\r\n"
                "Upgrade: websocket\r\n"
                "Connection: Upgrade\r\n"
                "Sec-WebSocket-Key: %s\r\n"
                "Sec-WebSocket-Version: 13\r\n"
                # Chromium 111+ requires Origin in --remote-allow-origins.
                "Origin: %s\r\n"
                "\r\n" % (path, hostport, clave, origin)
            ).encode()
        )
        buf = b""
        while b"\r\n\r\n" not in buf:
            trozo = self.s.recv(4096)
            if not trozo:
                raise RuntimeError("server closed during handshake")
            buf += trozo
        cabeceras, _, resto = buf.partition(b"\r\n\r\n")
        primera = cabeceras.split(b"\r\n")[0].decode(errors="replace")
        if "101" not in primera:
            raise RuntimeError("handshake rejected: %s" % primera)
        self.buf = resto

    def _leer(self, n):
        while len(self.buf) < n:
            trozo = self.s.recv(65536)
            if not trozo:
                raise RuntimeError("connection closed")
            self.buf += trozo
        out, self.buf = self.buf[:n], self.buf[n:]
        return out

    def enviar(self, texto):
        datos = texto.encode()
        n = len(datos)
        cab = bytearray([0x81])  # FIN + text opcode
        if n < 126:
            cab.append(0x80 | n)
        elif n < 1 << 16:
            cab.append(0x80 | 126); cab += struct.pack(">H", n)
        else:
            cab.append(0x80 | 127); cab += struct.pack(">Q", n)
        mascara = os.urandom(4)
        cab += mascara
        self.s.sendall(bytes(cab) + bytes(b ^ mascara[i % 4] for i, b in enumerate(datos)))

    def recibir(self):
        while True:
            b0, b1 = self._leer(2)
            opcode = b0 & 0x0F
            n = b1 & 0x7F
            if n == 126:
                n = struct.unpack(">H", self._leer(2))[0]
            elif n == 127:
                n = struct.unpack(">Q", self._leer(8))[0]
            carga = self._leer(n) if n else b""
            if b1 & 0x80:  # servers should not mask, but handle it just in case
                mascara, carga = carga[:4], carga[4:]
                carga = bytes(c ^ mascara[i % 4] for i, c in enumerate(carga))
            if opcode == 0x9:  # ping -> pong
                self.enviar("")
                continue
            if opcode == 0x8:
                raise RuntimeError("server closed the connection")
            if opcode in (0x1, 0x2):
                return carga.decode(errors="replace")

    def cerrar(self):
        try:
            self.s.close()
        except OSError:
            pass


# ---- 3. locate the xpui tab -------------------------------------------------
def objetivo(puerto):
    try:
        with urllib.request.urlopen("http://127.0.0.1:%d/json" % puerto, timeout=3) as r:
            objetivos = json.load(r)
    except Exception as e:
        morir("no debugging port on %d (%s). Spotify is closed or was launched "
               "without --remote-debugging-port" % (puerto, e), 2)
    paginas = [t for t in objetivos if t.get("type") == "page" and t.get("webSocketDebuggerUrl")]
    if not paginas:
        morir("port responds but no page is open", 3)
    # The main UI is xpui; fall back to the first page.
    for t in paginas:
        if "xpui" in (t.get("url") or ""):
            return t
    return paginas[0]


# ---- 4. JavaScript executed inside Spotify ----------------------------------
def construir_js(colores):
    return """(() => {
  const c = %s;
  const el = document.documentElement;
  const rgb = h => [parseInt(h.slice(0,2),16), parseInt(h.slice(2,4),16), parseInt(h.slice(4,6),16)];
  for (const k in c) {
    el.style.setProperty('--spice-' + k, '#' + c[k]);
    el.style.setProperty('--spice-rgb-' + k, rgb(c[k]).join(','));
  }
  return Object.keys(c).length;
})()""" % json.dumps(colores)


# ---- 5. main ----------------------------------------------------------------
def main():
    colores = leer_seccion(INI, SECCION)
    t = objetivo(PUERTO)
    ws = WS(t["webSocketDebuggerUrl"], "http://127.0.0.1:%d" % PUERTO)
    try:
        ws.enviar(json.dumps({
            "id": 1,
            "method": "Runtime.evaluate",
            "params": {"expression": construir_js(colores), "returnByValue": True},
        }))
        # An unrelated event may arrive before our response.
        for _ in range(20):
            msg = json.loads(ws.recibir())
            if msg.get("id") == 1:
                break
        else:
            morir("no response to evaluate", 4)
    finally:
        ws.cerrar()

    if "error" in msg:
        morir("CDP: %s" % msg["error"], 5)
    res = msg.get("result", {})
    if res.get("exceptionDetails"):
        morir("Spotify exception: %s" % res["exceptionDetails"].get("text"), 6)
    print("applied %s colors live" % res.get("result", {}).get("value"))


if __name__ == "__main__":
    main()
