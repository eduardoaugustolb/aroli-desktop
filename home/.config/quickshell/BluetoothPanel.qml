// BluetoothPanel.qml — bluetooth devices, unfolded FROM the notch.
// Sibling of NetworkPanel: same skeleton (header + switch + list) and
// same treatment from the control center. Talks to BlueZ via
// Quickshell.Bluetooth, no scripts. Discovery only runs while this
// panel is open (see ShellState.onPanelChanged).
import Quickshell
import Quickshell.Bluetooth
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    readonly property bool active: ShellState.panel === "bluetooth"
    readonly property var adapter: ShellState.btAdapter

    onActiveChanged: if (root.active) keys.forceActiveFocus()

    MouseArea { anchors.fill: parent }

    // Every panel must handle Escape (see the note in TopShell).
    Item {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: function (e) { ShellState.closePanel(); e.accepted = true; }
    }

    ColumnLayout {
        anchors { fill: parent; leftMargin: 22; rightMargin: 20; topMargin: 20; bottomMargin: 18 }
        spacing: 12

        // ─────────────── header ───────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                text: ShellState.btIcon
                color: ShellState.btConnected > 0 ? Colors.accent : (ShellState.btOn ? "#cfcfcf" : "#7d7d7d")
                font.family: Appearance.font; font.pixelSize: 18
            }
            ColumnLayout {
                spacing: 0
                Text {
                    text: I18n.tr("Bluetooth")
                    color: "#ffffff"
                    font.family: Appearance.fontUI; font.pixelSize: 13; font.weight: Font.DemiBold
                }
                Text {
                    text: !root.adapter ? I18n.tr("No adapter")
                        : ShellState.btBlocked ? I18n.tr("Blocked by rfkill")
                        : !ShellState.btOn ? I18n.tr("Off")
                        : ShellState.btConnected > 0
                            ? ShellState.btLabel(ShellState.btPaired[0])
                            : I18n.tr("Not connected")
                    color: "#8a8a8a"; elide: Text.ElideRight
                    font.family: Appearance.fontUI; font.pixelSize: 11
                }
            }
            Item { Layout.fillWidth: true }

            Rectangle {
                implicitWidth: 42; implicitHeight: 23
                radius: 12
                opacity: ShellState.btBlocked ? 0.4 : 1
                color: ShellState.btOn ? Colors.accent : Qt.rgba(1, 1, 1, 0.14)
                Behavior on color { ColorAnimation { duration: Appearance.mQuick; easing.type: Easing.OutQuad } }
                Rectangle {
                    width: 17; height: 17; radius: 9
                    color: "#ffffff"
                    y: 3
                    x: ShellState.btOn ? parent.width - width - 3 : 3
                    Behavior on x { NumberAnimation { duration: Appearance.mQuick; easing.type: Easing.OutCubic } }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    enabled: !ShellState.btBlocked
                    onClicked: ShellState.toggleBt()
                }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: "#1e1e1e" }

        // ─────────────── lists ───────────────
        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentHeight: lists.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded; width: 4 }

            ColumnLayout {
                id: lists
                width: parent.width
                spacing: 4

                Text {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    visible: ShellState.btPaired.length > 0
                    text: I18n.tr("MY DEVICES")
                    color: Colors.accent
                    font.family: Appearance.fontUI; font.pixelSize: 10
                    font.weight: Font.DemiBold; font.letterSpacing: 0.6
                }
                Repeater { model: ShellState.btPaired; BtRow {} }

                Text {
                    Layout.fillWidth: true
                    Layout.topMargin: 10
                    visible: ShellState.btOn && ShellState.btNearby.length > 0
                    text: I18n.tr("AVAILABLE")
                    color: Colors.accent
                    font.family: Appearance.fontUI; font.pixelSize: 10
                    font.weight: Font.DemiBold; font.letterSpacing: 0.6
                }
                Repeater { model: ShellState.btOn ? ShellState.btNearby : []; BtRow {} }
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !ShellState.btOn || (ShellState.btPaired.length === 0 && ShellState.btNearby.length === 0)
            text: !root.adapter ? I18n.tr("No bluetooth adapter")
                : ShellState.btBlocked
                    ? I18n.tr("The adapter is blocked by rfkill.")
                        + "\n" + I18n.tr("Unblock it with:  rfkill unblock bluetooth")
                : !ShellState.btOn ? I18n.tr("Bluetooth off")
                : I18n.tr("Looking for devices…")
            color: "#5e5e5e"
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            lineHeight: 1.5
            font.family: Appearance.fontUI; font.pixelSize: 12
        }
    }

    // ─────────── device row ───────────
    component BtRow: Rectangle {
        id: dev
        required property var modelData

        Layout.fillWidth: true
        Layout.preferredHeight: 46
        radius: 12
        color: dev.modelData.connected ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.18)
             : dMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04)
        Behavior on color { ColorAnimation { duration: Appearance.mQuick; easing.type: Easing.OutQuad } }

        RowLayout {
            anchors { fill: parent; leftMargin: 13; rightMargin: 12 }
            spacing: 11

            Text {
                text: dev.modelData.connected ? "󰂱" : "󰂯"
                color: dev.modelData.connected ? Colors.accent : "#cfcfcf"
                font.family: Appearance.font; font.pixelSize: 15
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Text {
                    Layout.fillWidth: true
                    text: ShellState.btLabel(dev.modelData)
                    color: "#ffffff"; elide: Text.ElideRight
                    font.family: Appearance.fontUI; font.pixelSize: 12
                    font.weight: dev.modelData.connected ? Font.DemiBold : Font.Normal
                }
                Text {
                    Layout.fillWidth: true
                    visible: text.length > 0
                    text: dev.modelData.pairing ? I18n.tr("Pairing…")
                        : dev.modelData.connected
                            ? (dev.modelData.batteryAvailable
                                ? I18n.tr("Connected · {0} %", Math.round(dev.modelData.battery * 100))
                                : I18n.tr("Connected"))
                        : (dev.modelData.paired || dev.modelData.bonded) ? I18n.tr("Paired") : ""
                    color: dev.modelData.connected ? Colors.accent : "#7d7d7d"
                    elide: Text.ElideRight
                    font.family: Appearance.fontUI; font.pixelSize: 10
                }
            }

            Text {
                visible: dMa.containsMouse && (dev.modelData.paired || dev.modelData.bonded)
                text: "󰩹"
                color: fMa.containsMouse ? Colors.crit : "#7d7d7d"
                font.family: Appearance.font; font.pixelSize: 13
                MouseArea {
                    id: fMa
                    anchors.fill: parent; anchors.margins: -6
                    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: dev.modelData.forget()
                }
            }
        }

        MouseArea {
            id: dMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            z: -1
            onClicked: {
                const d = dev.modelData;
                if (d.connected) d.disconnect();
                else if (d.paired || d.bonded) d.connect();
                else d.pair();
            }
        }
    }
}
