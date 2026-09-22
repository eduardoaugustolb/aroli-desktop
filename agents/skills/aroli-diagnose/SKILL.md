---
name: aroli-diagnose
description: >
  Use when something on the Aroli Desktop rice looks wrong, broke, is slow,
  or behaves unexpectedly: bar or notch missing, panel not opening, wallpaper
  not changing, colors stuck, service failed, login issue. Triggers: diagnose,
  debug, broken, stuck, failed unit, black screen, crash, freeze, error,
  warning, logs, journalctl, systemctl failed, hyprctl configerrors.
---

# Diagnose (read-only first, always)

Follow `aroli-desktop` laws: facts first, integrity first.

## 1. Triage (no writes)

```sh
./diagnose                                   # from the aroli-desktop checkout
hyprctl configerrors
systemctl --user is-active quickshell
systemctl --user --failed
journalctl --user -u quickshell -b --no-pager | tail -40
aroli status
```

`./diagnose` is read-only by design. Start there even when you think you
know the cause; paste the BAD lines verbatim to the user.

## 2. Narrow with logs, not guesses

- Quickshell/QML errors: `journalctl --user -u quickshell -b` filtered for
  the file you touched (`grep -i mediapanelfilename`).
- Hot reload usually applies `.qml` edits live; structural changes to the
  root window (TopShell) or new imports may need
  `~/.config/quickshell/reload.sh` (single-flight, do not stack reloads).
- A stale failure (unit failed hours ago, since fixed) clears with
  `systemctl --user reset-failed <unit>`; say so instead of re-fixing it.
- `aroli status` shows CLI version vs checkout VERSION vs latest release;
  mismatches there explain whole classes of weirdness.

## 3. Verify the fix where the user sees it

- Screenshot regions yourself (`grim -g "x,y wxh"`) and read the pixels:
  measure, do not eyeball. Check the journal again after the fix.
- Process claims need `ps`/`pgrep` evidence (start time, flags), not memory.
- If the fix holds, say what changed and the verification. If it is a
  product bug, go to `aroli-report`.
