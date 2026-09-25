#!/usr/bin/env python3
"""aroli-sys.py -- native host da Aroli: retrato completo da máquina.

Falado pelo navegador via stdin/stdout no protocolo de native messaging
(4 bytes little-endian + JSON).

  {"cmd":"sample"} -> snapshot: cpu (delta desde a amostra anterior;
  primeira: null), threads, mem/mem_used/mem_total, disk/disk_free/
  disk_total, temp/temp_word, uptime (s), bat (% ou null), charging.

  {"cmd":"set-frame","hex":"101111"} -> pinta o frame do Brave via o
  escritor oficial (sudo sem senha) e refresca o navegador. Hex validado
  à risca; qualquer outra coisa é ignorada. É assim que a chave de tema
  da página alcança o frame, que a policy gerenciada prende.

Só stdlib, sem loop próprio, sem timers: morre quando o navegador fecha
a porta (uma instância por guia visível). Instalado por install.sh em
~/.config/BraveSoftware/Brave-Origin/NativeMessagingHosts/aroli-sys.json.
"""
import json
import os
import re
import struct
import subprocess
import sys


def read(path):
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as f:
            return f.read().strip()
    except OSError:
        return ""


def cpu_times():
    try:
        parts = read("/proc/stat").splitlines()[0].split()[1:]
        nums = [int(x) for x in parts]
        total = sum(nums)
        idle = nums[3] + (nums[4] if len(nums) > 4 else 0)
        return total, idle
    except (IndexError, ValueError):
        return 0, 0


def mem():
    info = {}
    for line in read("/proc/meminfo").splitlines():
        key, _, val = line.partition(":")
        try:
            info[key] = int(val.split()[0]) * 1024
        except (ValueError, IndexError):
            pass
    total = info.get("MemTotal", 0)
    avail = info.get("MemAvailable", info.get("MemFree", 0))
    return total, max(0, total - avail)


def disk():
    try:
        st = os.statvfs("/")
        return st.f_blocks * st.f_frsize, st.f_bavail * st.f_frsize
    except OSError:
        return 0, 0


def temp_hwmon():
    """Melhor sensor de CPU via hwmon (k10temp/coretemp/zenpower primeiro)."""
    cpu_names = ("k10temp", "coretemp", "zenpower", "k8temp", "cpu_thermal")
    best_cpu = None
    fallback = None
    try:
        hwmons = sorted(os.listdir("/sys/class/hwmon"))
    except OSError:
        return None
    for hwmon in hwmons:
        base = "/sys/class/hwmon/%s" % hwmon
        name = read(base + "/name").lower()
        try:
            files = sorted(os.listdir(base))
        except OSError:
            continue
        for fname in files:
            if not (fname.startswith("temp") and fname.endswith("_input")):
                continue
            try:
                t = int(read(base + "/" + fname)) / 1000.0
            except ValueError:
                continue
            if not 0 < t < 150:
                continue
            if name.startswith(cpu_names):
                if best_cpu is None or t > best_cpu:
                    best_cpu = t
            elif fallback is None or t > fallback:
                fallback = t
    return best_cpu if best_cpu is not None else fallback


def temp_zones():
    best = None
    try:
        zones = os.listdir("/sys/class/thermal")
    except OSError:
        return None
    for zone in zones:
        if not zone.startswith("thermal_zone"):
            continue
        try:
            t = int(read("/sys/class/thermal/%s/temp" % zone)) / 1000.0
        except ValueError:
            continue
        if 0 < t < 150 and (best is None or t > best):
            best = t
    return best


def temp():
    return temp_hwmon() or temp_zones()


def temp_word(t):
    if t is None:
        return "n/a"
    if t < 52:
        return "Cool"
    if t < 68:
        return "Warm"
    if t < 80:
        return "Hot"
    return "Very hot"


def battery():
    try:
        bats = [d for d in os.listdir("/sys/class/power_supply") if d.startswith("BAT")]
    except OSError:
        return None, "unknown"
    if not bats:
        return None, "unknown"
    try:
        pct = int(read("/sys/class/power_supply/%s/capacity" % bats[0]))
    except ValueError:
        pct = None
    return pct, read("/sys/class/power_supply/%s/status" % bats[0]) or "unknown"


def uptime():
    try:
        return int(float(read("/proc/uptime").split()[0]))
    except (ValueError, IndexError):
        return 0


def pct(part, whole):
    if whole <= 0:
        return None
    return max(0.0, min(100.0, part / whole * 100.0))


def send(obj):
    data = json.dumps(obj).encode("utf-8")
    sys.stdout.buffer.write(struct.pack("<I", len(data)) + data)
    sys.stdout.buffer.flush()


def recv():
    raw = sys.stdin.buffer.read(4)
    if len(raw) < 4:
        return None
    (size,) = struct.unpack("<I", raw)
    if size > 1024 * 1024:
        return {}
    data = sys.stdin.buffer.read(size)
    if len(data) < size:
        return None
    try:
        return json.loads(data.decode("utf-8"))
    except ValueError:
        return {}


def set_frame(hexcolor):
    """Pinta o frame via o escritor oficial. Retorna True se aceito."""
    if not re.fullmatch(r"[0-9a-f]{6}", hexcolor or ""):
        return False
    try:
        subprocess.run(
            ["sudo", "-n", "omarchy-theme-set-browser-policy", hexcolor],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=10,
        )
    except (OSError, subprocess.SubprocessError):
        return False
    try:
        subprocess.Popen(
            ["brave-origin", "--refresh-platform-policy", "--no-startup-window"],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
    except OSError:
        pass
    return True


def snapshot(prev, msg):
    total, idle = cpu_times()
    cpu = None
    if prev is not None and total > prev[0]:
        cpu = max(0.0, min(100.0, (1.0 - (idle - prev[1]) / (total - prev[0])) * 100.0))
    prev = (total, idle)
    mem_total, mem_used = mem()
    disk_total, disk_free = disk()
    disk_used = max(0, disk_total - disk_free)
    t = temp()
    bpct, bstatus = battery()
    charging = bstatus.lower() == "charging"
    send({
        "cpu": cpu,
        "threads": os.cpu_count() or 0,
        "mem": pct(mem_used, mem_total),
        "mem_used": mem_used,
        "mem_total": mem_total,
        "disk": pct(disk_used, disk_total),
        "disk_free": disk_free,
        "disk_total": disk_total,
        "temp": t,
        "temp_word": temp_word(t),
        "uptime": uptime(),
        "bat": bpct,
        "charging": charging,
        "bat_status": bstatus,
    })
    return prev


def main():
    prev = None
    while True:
        msg = recv()
        if msg is None:
            break
        if isinstance(msg, dict) and msg.get("cmd") == "set-frame":
            send({"frame": set_frame(msg.get("hex", ""))})
            continue
        prev = snapshot(prev, msg)


if __name__ == "__main__":
    main()
