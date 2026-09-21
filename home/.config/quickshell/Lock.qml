// Lock.qml, Aroli lock screen entrypoint (notch band + central auth).
//
// Inspired by caelestia's morphing lock (badge -> auth surface, PAM states)
// painted with Aroli rules: the full-width notch band stays the surface,
// the wallpaper only supplies mood (blurred + dimmed) and accent, motion and
// radii come from Appearance, states keep fixed semantic colours.
//
// Trigger it with `qs ipc call lock lock` (hypridle lock_cmd does that) or
// Super+L (loginctl -> hypridle -> here). Remote/RustDesk sessions keep
// hyprlock (see hypridle.d/remote.conf).
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

Scope {
    id: root

    // The screen that owns the keyboard. Falls back to the first screen when
    // the focus seed has not arrived yet, so there is always exactly one.
    readonly property string primaryScreen: ShellState.focusedMon !== "" ? ShellState.focusedMon
        : (Quickshell.screens.length > 0 ? Quickshell.screens[0].name : "")

    LockPam {
        id: auth
    }

    WlSessionLock {
        id: lock

        LockSurface {
            lock: lock
            pam: auth
            primaryScreen: root.primaryScreen
        }
    }

    GlobalShortcut {
        name: "lock"
        description: I18n.tr("Lock the current session")
        onPressed: lock.locked = true
    }

    IpcHandler {
        target: "lock"

        function lock(): void {
            lock.locked = true;
        }

        function unlock(): void {
            lock.locked = false;
        }

        function isLocked(): bool {
            return lock.locked;
        }
    }
}
