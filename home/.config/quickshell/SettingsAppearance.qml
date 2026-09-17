// SettingsAppearance.qml — what used to require editing QML by hand.
// Everything writes to Config.qml and saves itself to
// ~/.config/quickshell-rice.json; the bar and notch react live as you drag
// the sliders.
//
// Descriptions are NOT painted here: they go in `hint` and the window shows
// them in the footer strip on hover (see SettingsControls.qml). Neither is the
// "Reset" button: the window's fixed header paints it from `actionText`.
import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Flickable {
    id: root

    // contract with SettingsWindow: header button and default footer text
    property string actionText: I18n.tr("Reset")
    property bool actionDanger: true
    property bool actionConfirm: true
    property string note: I18n.tr("Saved on its own to ~/.config/quickshell-rice.json")
    readonly property int matchCount: cLang.visibleRows + cNotch.visibleRows
        + cBehav.visibleRows + cBar.visibleRows + cFont.visibleRows + cFx.visibleRows
        + cWin.visibleRows + cWall.visibleRows
    signal actionRun
    onActionRun: Config.reset()

    contentHeight: col.implicitHeight + 34
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded; width: 5 }
    // returning to a section with the scroll halfway is disorienting
    onVisibleChanged: if (visible) contentY = 0

    ColumnLayout {
        id: col
        width: root.width - 48
        x: 24
        y: 16
        spacing: 10

        // ─────────────────── language ───────────────────
        // Goes first because it is the only thing on this page changing the
        // rest of the page. Both labels each go in their own language on
        // purpose: opening the shell in a language you cannot read, "English"
        // still registers.
        SettingsControls.Card_ {
            id: cLang
            title: I18n.tr("LANGUAGE")

            SettingsControls.Row_ {
                label: I18n.tr("Shell language")
                hint: I18n.tr("Changes the bar, the notch, the panels and this window. It does not touch the system language or the applications': it is only the shell. The change is immediate, nothing needs restarting.")
                SettingsControls.Choice_ {
                    options: I18n.labels
                    current: I18n.labelFor(Config.language)
                    onPicked: function (v) { Config.language = I18n.codeFor(v); Config.save(); }
                }
            }
        }

        // ─────────────────── notch shape ───────────────────
        SettingsControls.Card_ {
            id: cNotch
            title: I18n.tr("NOTCH")

            SettingsControls.Row_ {
                label: I18n.tr("Style")
                hint: I18n.tr("Notch: flush with the edge, with the MacBook's inverted corners. Island: a floating pill, rounded on all four sides, like the Dynamic Island.")
                SettingsControls.Choice_ {
                    // The label is translated, never the value going to JSON.
                    options: ["Notch", I18n.tr("Island")]
                    current: Config.notchStyle === "island" ? I18n.tr("Island") : "Notch"
                    onPicked: function (v) { Config.notchStyle = (v === I18n.tr("Island") ? "island" : "notch"); }
                }
            }

            SettingsControls.Row_ {
                label: I18n.tr("Colour")
                hint: I18n.tr("Pure black is the one that mimics the MacBook; the theme colour follows pywal.")
                SettingsControls.Choice_ {
                    options: [I18n.tr("Black"), I18n.tr("Theme")]
                    current: Config.notchColor.toString().toLowerCase() === "#000000" ? I18n.tr("Black") : I18n.tr("Theme")
                    onPicked: function (v) { Config.notchColor = (v === I18n.tr("Black") ? "#000000" : Colors.bg.toString()); }
                }
            }

            SettingsControls.Row_ {
                label: I18n.tr("Band height")
                hint: I18n.tr("Also the height of the notch at rest, and the space reserved at the top.")
                SettingsControls.Slider_ {
                    value: Config.bandH; from: 24; to: 48; suffix: " px"
                    onMoved: function (v) { Config.bandH = Math.round(v); }
                }
            }

            SettingsControls.Row_ {
                label: I18n.tr("Width at rest")
                hint: I18n.tr("For the clock on its own. If you turn on the date or the battery, the notch widens by itself.")
                SettingsControls.Slider_ {
                    value: Config.idleW; from: 110; to: 380; suffix: " px"
                    onMoved: function (v) { Config.idleW = Math.round(v); }
                }
            }

            SettingsControls.Row_ {
                shown: Config.notchStyle === "island"
                label: I18n.tr("Gap from the edge")
                hint: I18n.tr("How far the island sits from the edge of the screen. It comes out of the reserved band, so it covers nothing.")
                SettingsControls.Slider_ {
                    value: Config.islandGap; from: 0; to: 14; suffix: " px"
                    onMoved: function (v) { Config.islandGap = Math.round(v); }
                }
            }

            SettingsControls.Row_ {
                shown: Config.notchStyle !== "island"
                label: I18n.tr("Inverted corner")
                hint: I18n.tr("The concave sweep that joins the notch to the edge of the screen.")
                SettingsControls.Slider_ {
                    value: Config.flare; from: 0; to: 22; suffix: " px"
                    onMoved: function (v) { Config.flare = Math.round(v); }
                }
            }

            SettingsControls.Row_ {
                label: Config.notchStyle === "island" ? I18n.tr("Rounding") : I18n.tr("Bottom rounding")
                hint: I18n.tr("How much the corners of the notch round off when it is open.")
                SettingsControls.Slider_ {
                    value: Config.roundMax; from: 8; to: 40; suffix: " px"
                    onMoved: function (v) { Config.roundMax = Math.round(v); }
                }
            }
        }

        // ─────────────────── what it shows and when ───────────────────
        SettingsControls.Card_ {
            id: cBehav
            title: I18n.tr("BEHAVIOUR")

            SettingsControls.Row_ {
                label: I18n.tr("Hover delay")
                hint: I18n.tr("How long you have to stay on it before it opens. At 0 it opens as the pointer crosses.")
                SettingsControls.Slider_ {
                    value: Config.hoverDelay; from: 0; to: 900; suffix: " ms"
                    onMoved: function (v) { Config.hoverDelay = Math.round(v); }
                }
            }

            SettingsControls.Row_ {
                label: I18n.tr("Date at rest")
                hint: I18n.tr("At rest the notch shows only the time. With this it shows the date as well, and widens by itself to fit.")
                SettingsControls.Switch_ {
                    checked: Config.showDate
                    onToggled: function (v) { Config.showDate = v; }
                }
            }

            SettingsControls.Row_ {
                label: I18n.tr("Battery in the notch")
                hint: I18n.tr("The battery always shows on hover; this keeps it there at rest too.")
                SettingsControls.Switch_ {
                    checked: Config.showBattery
                    onToggled: function (v) { Config.showBattery = v; }
                }
            }

            SettingsControls.Row_ {
                label: I18n.tr("Reserve space")
                hint: I18n.tr("If you turn it off, windows go right up to the edge and the notch sits over them.")
                SettingsControls.Switch_ {
                    checked: Config.reserveSpace
                    onToggled: function (v) { Config.reserveSpace = v; }
                }
            }
        }

        // ─────────────────── bar ───────────────────
        SettingsControls.Card_ {
            id: cBar
            title: I18n.tr("BAR")

            SettingsControls.Row_ {
                label: I18n.tr("Background scrim")
                hint: I18n.tr("At 0 the bar is fully transparent. Raise it if you cannot read the glyphs over light wallpapers.")
                SettingsControls.Slider_ {
                    value: Config.scrimAlpha; from: 0; to: 0.7; decimals: 2
                    onMoved: function (v) { Config.scrimAlpha = v; }
                }
            }

            SettingsControls.Row_ {
                label: I18n.tr("Side margin")
                hint: I18n.tr("How far the end islands sit from the edge of the screen.")
                SettingsControls.Slider_ {
                    value: Config.sideMargin; from: 4; to: 48; suffix: " px"
                    onMoved: function (v) { Config.sideMargin = Math.round(v); }
                }
            }

            SettingsControls.Row_ {
                label: I18n.tr("Arch logo")
                hint: I18n.tr("The Arch glyph at the far left of the bar.")
                SettingsControls.Switch_ { checked: Config.showArch; onToggled: function (v) { Config.showArch = v; } }
            }
            SettingsControls.Row_ {
                label: I18n.tr("Workspaces")
                hint: I18n.tr("The workspace dots, with the active one stretched.")
                SettingsControls.Switch_ { checked: Config.showWorkspaces; onToggled: function (v) { Config.showWorkspaces = v; } }
            }
            SettingsControls.Row_ {
                label: I18n.tr("App name")
                hint: I18n.tr("The name of the window you have focused.")
                SettingsControls.Switch_ { checked: Config.showAppName; onToggled: function (v) { Config.showAppName = v; } }
            }
            SettingsControls.Row_ {
                label: I18n.tr("System tray")
                hint: I18n.tr("The icons apps publish: nm-applet, rustdesk and so on.")
                SettingsControls.Switch_ { checked: Config.showTray; onToggled: function (v) { Config.showTray = v; } }
            }
        }

        // ─────────────────── typography ───────────────────
        SettingsControls.Card_ {
            id: cFont
            title: I18n.tr("TYPOGRAPHY")

            SettingsControls.Row_ {
                label: I18n.tr("Notch font")
                hint: I18n.tr("Proportional, only for the text inside the notch. The icons always use the Nerd Font.")
                SettingsControls.Choice_ {
                    options: Config.fontChoices
                    current: Config.fontUI
                    onPicked: function (v) { Config.fontUI = v; }
                }
            }

            SettingsControls.Row_ {
                label: I18n.tr("Clock size")
                hint: I18n.tr("The notch clock at rest.")
                SettingsControls.Slider_ {
                    value: Config.clockSize; from: 12; to: 24; suffix: " px"
                    onMoved: function (v) { Config.clockSize = Math.round(v); }
                }
            }
        }

        // ─────────────────── compositor effects ───────────────────
        // The only card on the page ruling nothing the shell paints: this is
        // Hyprland's. So the setting also goes to ~/.config/hypr/effects.lua
        // and not just the JSON the footer announces — the why of both paths
        // lives in Config.applyEffects().
        SettingsControls.Card_ {
            id: cFx
            title: I18n.tr("EFFECTS")

            SettingsControls.Row_ {
                label: I18n.tr("Motion blur")
                hint: I18n.tr("The window blurs in the direction it is travelling, for as long as the animation lasts. Transitions only: dragging with the mouse already tracks your hand 1:1 and leaves no trail. If battery is tight, this is the first thing to turn off.")
                SettingsControls.Switch_ {
                    checked: Config.motionBlur
                    onToggled: function (v) { Config.motionBlur = v; Config.applyEffects(); }
                }
            }

            SettingsControls.Row_ {
                shown: Config.motionBlur
                label: I18n.tr("Samples")
                hint: I18n.tr("How many copies of the window are averaged along its path. More samples, smoother trail and more expensive to draw. It does not lengthen the trail: that is decided by how far the window has moved.")
                SettingsControls.Slider_ {
                    value: Config.motionBlurSamples; from: 2; to: 24
                    onMoved: function (v) { Config.motionBlurSamples = Math.round(v); Config.applyEffects(); }
                }
            }
        }

        // ─────────────────── windows ───────────────────
        // Like EFFECTS: this is Hyprland's, not the shell's. It also goes to
        // ~/.config/hypr/effects.lua via Config.applyEffects() — see Config.
        SettingsControls.Card_ {
            id: cWin
            title: I18n.tr("WINDOWS")

            SettingsControls.Row_ {
                label: I18n.tr("Rounded corners")
                hint: I18n.tr("How much window corners round off. At 0 they stay square. With rounding, corners go square while the window travels: that is a Hyprland limit, not a bug.")
                SettingsControls.Slider_ {
                    value: Config.windowRounding; from: 0; to: 20; suffix: " px"
                    onMoved: function (v) { Config.windowRounding = Math.round(v); Config.applyEffects(); }
                }
            }

            SettingsControls.Row_ {
                label: I18n.tr("Window border")
                hint: I18n.tr("Border thickness, themed with pywal. At 0 focus is shown with light and shadow alone.")
                SettingsControls.Slider_ {
                    value: Config.windowBorderSize; from: 0; to: 4; suffix: " px"
                    onMoved: function (v) { Config.windowBorderSize = Math.round(v); Config.applyEffects(); }
                }
            }

            SettingsControls.Row_ {
                label: I18n.tr("Gap between windows")
                hint: I18n.tr("Gap between two windows. The visible gap is double: 3 and 3 meet at 6.")
                SettingsControls.Slider_ {
                    value: Config.windowGapsIn; from: 0; to: 20; suffix: " px"
                    onMoved: function (v) { Config.windowGapsIn = Math.round(v); Config.applyEffects(); }
                }
            }

            SettingsControls.Row_ {
                label: I18n.tr("Gap to the edge")
                hint: I18n.tr("Gap between windows and the edge of the screen. Matching it to double the previous one keeps the same gap everywhere.")
                SettingsControls.Slider_ {
                    value: Config.windowGapsOut; from: 0; to: 30; suffix: " px"
                    onMoved: function (v) { Config.windowGapsOut = Math.round(v); Config.applyEffects(); }
                }
            }
        }

        // ─────────────────── wallpaper ───────────────────
        SettingsControls.Card_ {
            id: cWall
            title: I18n.tr("WALLPAPER")

            SettingsControls.Action_ {
                label: I18n.tr("Change wallpaper")
                hint: I18n.tr("Opens the picker: your own wallpapers and a web search. Apply one and pywal recolours the whole desktop.")
                icon: Icons.image
                value: "Super+Shift+W"
                // This button already broke TWICE for the same reason —the
                // text sent is not what Hyprland expects— and both times it
                // failed silently, doing NOTHING when pressed. Worth leaving
                // both written down, because the symptom is identical:
                //
                // 1. "global,quickshell:wallpaper" was sent, copying the comma
                //    from `bind =`. Over IPC the comma separates nothing: the
                //    first token IS the dispatcher name, and "global," does not
                //    exist.
                // 2. Even spaced, "global quickshell:wallpaper" stopped working
                //    in Hyprland 0.55: the `dispatch` argument became a LUA
                //    EXPRESSION, and as such `global quickshell:wallpaper` is a
                //    syntax error. Now the true dispatcher, `hl.dsp.global`, is
                //    called with the global-shortcut name the WallpaperPicker.qml
                //    GlobalShortcut declares.
                //
                // The moral of both: if this button never answers, first look at
                // `journalctl --user -u quickshell` or try the same text with
                // `hyprctl dispatch '...'`, because the error stays in Hyprland
                // and never reaches the UI.
                onTriggered: Hyprland.dispatch('hl.dsp.global("quickshell:wallpaper")')
            }
        }

        SettingsControls.Note_ {
            Layout.topMargin: 10
            visible: ShellState.settingsQuery.length > 0
                     && !cLang.visible && !cNotch.visible && !cBehav.visible && !cBar.visible
                     && !cFont.visible && !cFx.visible && !cWin.visible && !cWall.visible
            text: I18n.tr("No Appearance setting matches “{0}”.", ShellState.settingsQuery)
        }
    }
}
