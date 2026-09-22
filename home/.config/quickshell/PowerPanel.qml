// PowerPanel.qml, power menu unfolded FROM the notch.
// Replaces wlogout, which took the whole screen. Here it is a row of
// five buttons inside the notch: ←/→ or Tab to move, Enter confirms,
// Esc closes. TopShell provides keyboard focus.
//
// Log out, Restart, and Shut down ask for TWO Enters: the first arms the button
// (it turns red and its label becomes "Sure?"), the second runs. Lock and
// Suspend do not ask: you lose nothing and coming back costs one keystroke.
// Anything other than repeating Enter disarms: moving to another button,
// Esc, or leaving it idle a few seconds.
import Quickshell
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    readonly property bool active: ShellState.panel === "power"
    property int current: 0

    readonly property var items: [
        { icon: "󰌾", label: I18n.tr("Lock"),  cmd: "loginctl lock-session",              danger: false },
        { icon: "󰤄", label: I18n.tr("Suspend"), cmd: "systemctl suspend",     danger: false },
        // Bare `exit` no longer works: since Hyprland 0.55 the
        // `dispatch` argument is a Lua expression, and a bare name stays nil
        // ("expected a dispatcher"). The single quotes are needed so the
        // parentheses reach hyprctl intact; cmd runs under `bash -lc`, so
        // nobody eats them along the way.
        { icon: "󰗽", label: I18n.tr("Log out"),     cmd: "hyprctl dispatch 'hl.dsp.exit()'", danger: false, confirm: true  },
        { icon: "󰜉", label: I18n.tr("Restart"), cmd: "systemctl reboot",      danger: true,  confirm: true  },
        { icon: "󰐥", label: I18n.tr("Shut down"),    cmd: "systemctl poweroff",    danger: true,  confirm: true  }
    ]

    // Armed button index, or -1. Only used by actions with
    // confirm: true; the rest run on the first Enter as always.
    property int armed: -1

    // An armed button does not stay armed forever: if you get distracted and
    // come back, the next Enter will not shut down your laptop. Not a
    // motion duration, a wait, which is why it does not come from Appearance.
    Timer { id: armTimer; interval: 4000; onTriggered: root.armed = -1 }

    function disarm() { root.armed = -1; armTimer.stop(); }

    function select(i) {
        if (i === root.current) return;   // staying on the same button does not disarm
        root.current = i;
        root.disarm();
    }

    function run(i) {
        if (i < 0 || i >= root.items.length) return;
        // First Enter on a destructive action: arm and wait for the second.
        if (root.items[i].confirm && root.armed !== i) {
            root.armed = i;
            armTimer.restart();
            return;
        }
        const cmd = root.items[i].cmd;
        root.disarm();
        ShellState.closePanel();
        Quickshell.execDetached(["bash", "-lc", cmd]);
    }
    function move(d) {
        let i = root.current + d;
        if (i < 0) i = root.items.length - 1;
        if (i >= root.items.length) i = 0;
        root.select(i);
    }

    // Always starts on "Lock": the least destructive. A stray Enter
    // cannot shut down your laptop.
    onActiveChanged: if (root.active) { root.current = 0; root.disarm(); keys.forceActiveFocus(); }

    MouseArea { anchors.fill: parent }

    Item {
        id: keys
        anchors.fill: parent
        focus: true
        // Esc with an armed button only cancels the confirmation; the second Esc
        // closes the panel. Leaving an armed state never closes the menu on you.
        Keys.onEscapePressed: if (root.armed >= 0) root.disarm(); else ShellState.closePanel()
        Keys.onLeftPressed: root.move(-1)
        Keys.onRightPressed: root.move(1)
        Keys.onReturnPressed: root.run(root.current)
        Keys.onEnterPressed: root.run(root.current)
        Keys.onTabPressed: root.move(1)
        Keys.onBacktabPressed: root.move(-1)

        RowLayout {
            anchors { fill: parent; leftMargin: 22; rightMargin: 22; topMargin: 20; bottomMargin: 18 }
            spacing: 12

            Repeater {
                model: root.items

                Rectangle {
                    id: btn
                    required property var modelData
                    required property int index
                    readonly property bool sel: index === root.current
                    readonly property bool isArmed: index === root.armed

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Appearance.radM
                    color: btn.isArmed
                        ? Qt.rgba(Colors.crit.r, Colors.crit.g, Colors.crit.b, 0.52)
                        : btn.sel
                        ? (modelData.danger ? Qt.rgba(Colors.crit.r, Colors.crit.g, Colors.crit.b, 0.26)
                                            : Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.26))
                        : bMa.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.05)
                    Behavior on color { ColorAnimation { duration: Appearance.mQuick; easing.type: Easing.OutQuad } }
                    scale: bMa.pressed ? 0.95 : 1
                    Behavior on scale { SpringAnimation { spring: Appearance.sprTight; damping: Appearance.dmpTight; epsilon: Appearance.eppScale } }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: btn.modelData.icon
                            color: btn.isArmed ? Colors.inkHi
                                : btn.sel ? (btn.modelData.danger ? Colors.crit : Colors.accent) : Colors.inkMid
                            font.family: Appearance.font; font.pixelSize: Appearance.fsTitle
                        }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: btn.isArmed ? I18n.tr("Sure?") : btn.modelData.label
                            color: btn.sel ? Colors.inkHi : "#8a8a8a"
                            font.family: Appearance.fontUI; font.pixelSize: Appearance.fsXS
                            font.weight: btn.sel ? Font.Medium : Font.Normal
                        }
                    }

                    MouseArea {
                        id: bMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.select(btn.index)
                        onClicked: root.run(btn.index)
                    }
                }
            }
        }
    }
}
