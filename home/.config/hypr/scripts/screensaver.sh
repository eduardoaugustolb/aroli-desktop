#!/usr/bin/env bash
# Random terminal screensaver (exit with q / Ctrl+C).
savers=("pipes.sh -t 0 -f 60" "cbonsai -l -i -w 0.5" "cmatrix -ab" "tty-clock -c -C 4 -s -D")
pick="${savers[$RANDOM % ${#savers[@]}]}"
# If kitty dies before pipes.sh exits from a keypress, its loop is orphaned at
# 25% CPU and only SIGKILL stops it. Sweep before launch and kill on exit; the
# pattern is anchored to this script's exact arguments to avoid other pipes.sh.
# The initial sweep removes any previous screensaver still alive: only one makes
# sense at a time.
pkill -KILL -f 'pipes\.sh -t 0 -f 60' 2>/dev/null || true
kitty --start-as=fullscreen -o confirm_os_window_close=0 sh -c "$pick"
pkill -KILL -f 'pipes\.sh -t 0 -f 60' 2>/dev/null || true
