// SettingsBluetooth.qml - dispositivos bluetooth vía Quickshell.Bluetooth (Bluez),
// sustituyendo al menú de rofi. Emparejar, conectar, desconectar y olvidar.
//
// LO QUE ARREGLA ESTA VERSIÓN: si el adaptador está bloqueado por rfkill (que
// es como está normalmente este portátil, por batería), la pantalla decía
// "Bluetooth apagado, enciéndelo con el interruptor" - y el interruptor no
// hacía absolutamente nada, porque con un soft-block Bluez ignora el `enabled`.
// Ahora se dice claro, el interruptor se apaga para no mentir, y hay un botón
// que hace el `rfkill unblock` (el usuario tiene ACL sobre /dev/rfkill, así que
// no hace falta sudo).
import Quickshell
import Quickshell.Bluetooth
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Flickable {
    id: root

    property string note: I18n.tr("It only looks for devices while this section is open.")
    readonly property int matchCount: cAdapter.visibleRows + cPaired.visibleRows + cNearby.visibleRows

    contentHeight: col.implicitHeight + 34
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded; width: 5 }
    onVisibleChanged: {
        if (visible) contentY = 0;
        // el descubrimiento lo gobierna un único Binding en ShellState
        ShellState.btScanWanted = visible;
    }
    Component.onDestruction: ShellState.btScanWanted = false

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool blocked: ShellState.btBlocked
    readonly property bool on_: root.adapter ? root.adapter.enabled : false

    ColumnLayout {
        id: col
        width: root.width - 48
        x: 24
        y: 16
        spacing: 10

        SettingsControls.Card_ {
            id: cAdapter
            title: I18n.tr("ADAPTER")

            SettingsControls.Row_ {
                label: I18n.tr("Bluetooth")
                active: !root.blocked && root.adapter !== null
                hint: root.blocked
                    ? I18n.tr("It cannot be switched on: the radio is blocked by rfkill (soft-block). Unblock it below.")
                    : I18n.tr("Switches the adapter on and off.")
                SettingsControls.Switch_ {
                    checked: root.on_
                    live: !root.blocked && root.adapter !== null
                    onToggled: function (v) { if (root.adapter) root.adapter.enabled = v; }
                }
            }

            SettingsControls.Action_ {
                shown: root.blocked
                label: I18n.tr("Unblock the radio")
                hint: I18n.tr("Runs “rfkill unblock bluetooth”. It is usually blocked on purpose to save battery.")
                icon: "󰂲"
                value: "rfkill"
                onTriggered: Quickshell.execDetached(["rfkill", "unblock", "bluetooth"])
            }
        }

        SettingsControls.Note_ {
            Layout.topMargin: 4
            visible: !root.adapter
            text: I18n.tr("There is no bluetooth adapter on this machine.")
        }

        // Este estado hay que explicarlo sin tener que pasar el ratón: un
        // interruptor apagado que además no responde parece la app rota.
        SettingsControls.Note_ {
            Layout.topMargin: 4
            visible: root.blocked
            text: I18n.tr("The radio is blocked by rfkill (soft-block), so Bluez ignores the switch. It is usually left like this on purpose to save battery.")
        }

        SettingsControls.Card_ {
            id: cPaired
            title: I18n.tr("MY DEVICES")

            Repeater {
                model: ShellState.btPaired
                onItemAdded: cPaired.recount()
                onItemRemoved: cPaired.recount()
                DevRow {}
            }
        }

        SettingsControls.Card_ {
            id: cNearby
            title: I18n.tr("AVAILABLE")

            Repeater {
                model: root.on_ ? ShellState.btNearby : []
                onItemAdded: cNearby.recount()
                onItemRemoved: cNearby.recount()
                DevRow {}
            }
        }

        SettingsControls.Empty_ {
            Layout.topMargin: 4
            visible: ShellState.settingsQuery.length === 0
                && root.on_ && ShellState.btNearby.length === 0
            icon: "󰂯"
            title: I18n.tr("Looking for devices")
            body: I18n.tr("Bring the device close and put it into pairing mode. It will show up here as soon as Bluez finds it.")
        }

        SettingsControls.Empty_ {
            Layout.topMargin: 4
            visible: ShellState.settingsQuery.length === 0 && !root.on_ && !root.blocked
                && root.adapter !== null && ShellState.btPaired.length === 0
            icon: "󰂲"
            title: I18n.tr("Bluetooth is off")
            body: I18n.tr("Switch it on above to find and pair nearby devices.")
        }
    }

    // ─────────── fila de dispositivo ───────────
    component DevRow: Rectangle {
        id: dev
        required property var modelData

        readonly property string name_: ShellState.btLabel(dev.modelData)
        readonly property string state_: dev.modelData.pairing ? I18n.tr("Pairing…")
            : dev.modelData.connected
                ? (dev.modelData.batteryAvailable
                    ? I18n.tr("Connected · {0} %", Math.round(dev.modelData.battery * 100))
                    : I18n.tr("Connected"))
            : ShellState.btFailureFor === (dev.modelData.address || "")
                ? I18n.tr("Couldn’t connect · try again")
                : (dev.modelData.paired || dev.modelData.bonded) ? I18n.tr("Paired") : ""

        readonly property bool isSettingsRow: true
        readonly property bool matches: ShellState.settingsMatch(dev.name_, dev.modelData.address || "")
        function _recount() {
            let p = dev.parent;
            while (p) { if (p.isSettingsCard) { p.recount(); return; } p = p.parent; }
        }
        onMatchesChanged: dev._recount()
        Component.onCompleted: dev._recount()

        Layout.fillWidth: true
        Layout.preferredHeight: 44
        visible: dev.matches
        radius: Appearance.radS
        color: dev.modelData.connected ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.18)
             : dMa.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : "transparent"
        Behavior on color { ColorAnimation { duration: Appearance.mQuick; easing.type: Easing.OutQuad } }

        RowLayout {
            anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
            spacing: 12

            Text {
                text: dev.modelData.connected ? "󰂱" : "󰂯"
                color: dev.modelData.connected ? Colors.accent : "#9a9a9a"
                font.family: Appearance.font
                font.pixelSize: 15
            }

            Text {
                Layout.fillWidth: true
                text: dev.name_
                color: "#ffffff"
                elide: Text.ElideRight
                font.family: Appearance.fontUI
                font.pixelSize: Appearance.fsS
                font.weight: dev.modelData.connected ? Font.Medium : Font.Normal
            }

            Text {
                visible: dev.state_.length > 0
                text: dev.state_
                color: dev.modelData.connected ? Colors.accent
                     : ShellState.btFailureFor === (dev.modelData.address || "") ? Colors.crit : "#7d7d7d"
                font.family: Appearance.fontUI
                font.pixelSize: Appearance.fsXS
            }

            Text {
                text: dev.modelData.connected ? I18n.tr("Disconnect")
                    : (dev.modelData.paired || dev.modelData.bonded) ? I18n.tr("Connect") : I18n.tr("Pair")
                color: actionMa.containsMouse ? Colors.accent : "#b0b0b0"
                font.family: Appearance.fontUI
                font.pixelSize: Appearance.fsXS
                MouseArea {
                    id: actionMa
                    anchors.fill: parent; anchors.margins: -6
                    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: ShellState.connectBluetooth(dev.modelData)
                }
            }

            // Forget stays visible for saved devices: it is a first-class
            // recovery action, not a hover-only hidden affordance.
            Text {
                visible: dev.modelData.paired || dev.modelData.bonded
                text: "󰩹"
                color: fMa.containsMouse ? Colors.crit : "#7d7d7d"
                font.family: Appearance.font
                font.pixelSize: 13
                MouseArea {
                    id: fMa
                    anchors.fill: parent
                    anchors.margins: -6
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: ShellState.settingsHint = I18n.tr("Forget “{0}”: removes the pairing.", dev.name_)
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
            onEntered: ShellState.settingsHint = dev.modelData.address
                ? dev.name_ + " · " + dev.modelData.address
                : dev.name_
            onExited: ShellState.settingsHint = ""
            onClicked: {
                ShellState.connectBluetooth(dev.modelData);
            }
        }
    }
}
