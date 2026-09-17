// Config.qml — persistent rice settings.
//
// Everything that used to be hardcoded constants in TopShell/ShellState lives
// here and is saved to ~/.config/quickshell-rice.json. The Settings app writes
// over this and the bar and notch react live.
//
// NOTE the path: the file goes OUTSIDE ~/.config/quickshell/ on purpose.
// Quickshell watches its config directory for hot reload, and saving in there
// every time you drag a slider would fire one reload per pixel.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // ───────── language ─────────
    // "pt-BR" | "es" | "en". I18n reads it and the whole UI hangs off it. The
    // installer leaves it written per what you pick at install time (./install.sh --lang pt-BR).
    property alias language: opts.language

    // ───────── notch ─────────
    // "notch" = island glued to the edge with inverted corners (MacBook).
    // "island" = floating pill detached from the edge (Dynamic Island).
    property alias notchStyle: opts.notchStyle
    property alias islandGap: opts.islandGap
    readonly property bool island: opts.notchStyle === "island"

    property alias notchColor: opts.notchColor
    property alias bandH: opts.bandH            // band height = resting notch height
    property alias flare: opts.flare            // inverted top-corner radius
    property alias roundMax: opts.roundMax      // max bottom radius
    property alias idleW: opts.idleW            // resting width for the CLOCK ALONE; grows if you enable date or battery
    property alias hoverDelay: opts.hoverDelay  // ms before opening the "peek"
    property alias showDate: opts.showDate
    property alias showBattery: opts.showBattery
    property alias reserveSpace: opts.reserveSpace

    // ───────── bar ─────────
    property alias scrimAlpha: opts.scrimAlpha  // veil under the bar (0 = transparent)
    property alias sideMargin: opts.sideMargin
    property alias showArch: opts.showArch
    property alias showWorkspaces: opts.showWorkspaces
    property alias showAppName: opts.showAppName
    property alias showTray: opts.showTray

    // ───────── launcher ─────────
    // Favorites, by .desktop entry `id` and IN ORDER: position is what
    // the user arranges by dragging, so the list is the data, not a set.
    property alias favApps: opts.favApps

    // ───────── compositor effects ─────────
    // These two are not the shell's: they belong to Hyprland. They are stored
    // here like the rest so Settings stays a single place, but reaching
    // Hyprland is another matter — see applyEffects() below.
    property alias motionBlur: opts.motionBlur
    property alias motionBlurSamples: opts.motionBlurSamples

    // ───────── windows ─────────
    // Corner radius and border thickness (Hyprland: decoration:rounding and
    // general:border_size). The border already comes themed via pywal; with 0,
    // focus stays marked by light/shadow alone. Gaps: gaps_in between windows,
    // gaps_out to the screen edge (Hyprland: general:gaps_in/gaps_out).
    property alias windowRounding: opts.windowRounding
    property alias windowBorderSize: opts.windowBorderSize
    property alias windowGapsIn: opts.windowGapsIn
    property alias windowGapsOut: opts.windowGapsOut

    // ───────── typography ─────────
    property alias fontUI: opts.fontUI
    property alias clockSize: opts.clockSize

    readonly property var fontChoices: [
        "Adwaita Sans", "Google Sans Flex", "Rubik", "Red Hat Text",
        "Space Grotesk", "Readex Pro", "Noto Sans"
    ]

    function save() { file.writeAdapter(); }

    // Hyprland does not read quickshell-rice.json, so the setting must travel
    // two ways, and BOTH are needed:
    //
    //   hyprctl eval    applies it live, so it shows when you flip
    //                   the switch and not at reboot.
    //   effects.lua     writes it down. hyprland.lua loads it last with a
    //                   guarded dofile, so it survives `hyprctl reload`
    //                   —which would reread the config and wipe the
    //                   eval— and session restarts.
    //
    // The file is ALWAYS written, even if the eval fails: if Hyprland is not
    // listening, the setting is not lost, it just waits until the next
    // boot. The reverse would not do.
    // The debounce lives here and not in the UI on purpose: the samples
    // slider fires on EVERY pixel of the drag with no "released" signal,
    // so without this one drag would launch a hundred processes and a hundred
    // file rewrites. Callers need not know — just call.
    function applyEffects() { debounce.restart(); }

    Timer {
        id: debounce
        interval: 180
        onTriggered: {
            const lua = "hl.config({ general = { border_size = " + opts.windowBorderSize
                      + ", gaps_in = " + opts.windowGapsIn + ", gaps_out = " + opts.windowGapsOut + " }, "
                      + "decoration = { rounding = " + opts.windowRounding + ", "
                      + "motion_blur = { enabled = "
                      + (opts.motionBlur ? "true" : "false")
                      + ", samples = " + opts.motionBlurSamples + " } } })";
            // The values are bool/int from the JsonAdapter, never free user
            // text, so nobody can break out of these single quotes by
            // writing.
            fx.command = ["sh", "-c",
                "hyprctl eval '" + lua + "' >/dev/null 2>&1; "
                + "printf '%s\\n' "
                + "'-- Generated by Settings > Appearance > Effects. Rewritten on its own: do not edit by hand.' "
                + "'" + lua + "' > \"$HOME/.config/hypr/effects.lua\""];
            fx.running = true;
        }
    }

    Process { id: fx }

    // On shell startup there is nothing to apply: hyprland.lua has already read
    // effects.lua. This is only for when the JSON is touched from outside —by
    // hand, or by the installer— and the two files have drifted apart.
    Component.onCompleted: root.applyEffects()

    function reset() {
        opts.notchStyle = "notch"; opts.islandGap = 4;
        opts.notchColor = "#000000";
        opts.bandH = 32; opts.flare = 13; opts.roundMax = 30; opts.idleW = 140;
        opts.hoverDelay = 240;
        opts.showDate = false; opts.showBattery = false; opts.reserveSpace = true;
        opts.scrimAlpha = 0.0; opts.sideMargin = 16;
        opts.showArch = true; opts.showWorkspaces = true;
        opts.showAppName = true; opts.showTray = true;
        opts.fontUI = "Adwaita Sans"; opts.clockSize = 17;
        opts.motionBlur = true; opts.motionBlurSamples = 7;
        opts.windowRounding = 12; opts.windowBorderSize = 0;
        opts.windowGapsIn = 3; opts.windowGapsOut = 6;
        root.applyEffects();   // this one does not catch on by itself: it must be pushed to Hyprland
        // favApps and language are NOT touched on purpose: "restore defaults"
        // is about appearance, and neither your favorites nor the language you
        // read the screen in is a default worth resetting.
        root.save();
    }

    FileView {
        id: file
        path: Quickshell.env("HOME") + "/.config/quickshell-rice.json"
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        // First time: missing -> created with the defaults.
        onLoadFailed: function (error) {
            if (error === FileViewError.FileNotFound) writeAdapter();
        }

        JsonAdapter {
            id: opts

            property string language: "pt-BR"

            property string notchStyle: "notch"
            property int islandGap: 4
            property string notchColor: "#000000"
            property int bandH: 32
            property int flare: 13
            property int roundMax: 30
            property int idleW: 140
            property int hoverDelay: 240
            property bool showDate: false   // at rest clock and battery only; the full date shows on hover
            property bool showBattery: false
            property bool reserveSpace: true

            property real scrimAlpha: 0.0
            property int sideMargin: 16
            property bool showArch: true
            property bool showWorkspaces: true
            property bool showAppName: true
            property bool showTray: true

            // Factory-on: one of the few rice things visible
            // without touching anything. The switch is there for the day
            // battery matters more than the trail.
            property bool motionBlur: true
            property int motionBlurSamples: 7

            // Window corner rounding (0 = square). 12 is the default: reads
            // as "floating" without turning pill-shaped. Border 0 = focus by
            // light/shadow alone. Gaps 3/6: 6 px between two windows (3 + 3)
            // and 6 more to the screen edge — the same gap.
            property int windowRounding: 12
            property int windowBorderSize: 0
            property int windowGapsIn: 3
            property int windowGapsOut: 6

            property string fontUI: "Adwaita Sans"
            property int clockSize: 17

            property list<string> favApps: []
        }
    }
}
