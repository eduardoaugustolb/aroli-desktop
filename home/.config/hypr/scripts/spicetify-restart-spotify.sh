#!/usr/bin/env bash
# Restarts Spotify and returns it to its workspace silently, without switching
# focus. Called by spicetify-pywal.sh in the background.
#   $1 = Spotify's former workspace ID (empty = do not move)
set -u

WS="${1:-}"

# Close Spotify (SIGTERM; SIGKILL if needed).
pkill -x spotify 2>/dev/null
for i in $(seq 1 12); do pgrep -x spotify >/dev/null 2>&1 || break; sleep 0.25; done
pgrep -x spotify >/dev/null 2>&1 && pkill -9 -x spotify 2>/dev/null
sleep 0.3

# Relaunch WITH the debugging port so spicetify-push-colors.py can recolor live
# next time. The desktop entry covers menu launches; this covers this script.
FLAGS="--remote-debugging-port=9333 --remote-allow-origins=http://127.0.0.1:9333"
# Lua syntax (Hyprland 0.55+): bare `exec` is no longer valid Lua. The fallback
# still launched Spotify, but silently lost its return to the workspace.
hyprctl dispatch "hl.dsp.exec_cmd(\"spotify $FLAGS\")" >/dev/null 2>&1 || setsid spotify $FLAGS >/dev/null 2>&1

# Return it to its workspace once the window appears (silent keeps focus).
[ -n "$WS" ] || exit 0
for i in $(seq 1 40); do
  hyprctl clients -j 2>/dev/null | grep -q '"class": "Spotify"' && break
  sleep 0.5
done
sleep 0.6
# `follow = false` is Lua's equivalent of movetoworkspacesilent.
hyprctl dispatch "hl.dsp.window.move({ workspace = $WS, follow = false, window = \"class:^(Spotify)$\" })" >/dev/null 2>&1
