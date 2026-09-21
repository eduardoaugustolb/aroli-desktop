// shell.qml, entrypoint. Instantiates the Quickshell system components.
// The dashboard/sidebar was removed: its content lives in the notch
// control center (ControlPanel.qml). Super+N now toggles notch <-> island.
//
// The fullscreen Overview was ALSO removed (Aug 6, 2026): it is now one more
// notch face (OverviewPanel.qml), so it is no longer a standalone window and
// is not instantiated here. Its shortcut, Super+Tab, has not changed.
import Quickshell

Scope {
    id: root
    TopShell {}     // bar + notch on a single surface (replaces waybar)
    SettingsWindow {}   // Settings app (floating window, launched from the notch)
    MediaControls {}
    WallpaperPicker {}
    Lock {}         // Threshold lock screen (WlSessionLock + PAM, caelestia-inspired)
}
