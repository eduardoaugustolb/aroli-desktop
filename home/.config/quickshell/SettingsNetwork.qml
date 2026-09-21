// SettingsNetwork.qml - Wi-Fi is a first-class Settings section, not a
// relocated notch picker. Saved profiles can be connected or forgotten here.
import Quickshell
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Flickable {
    id: root
    property string askingFor: ""
    property string passwordDraft: ""
    property string errorFor: ""
    contentHeight: col.implicitHeight + 34
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded; width: 5 }
    onVisibleChanged: {
        if (visible) contentY = 0;
        ShellState.wifiScanWanted = visible;
    }
    Component.onDestruction: ShellState.wifiScanWanted = false

    ColumnLayout {
        id: col
        width: root.width - 48; x: 24; y: 16; spacing: 10

        SettingsControls.Card_ {
            title: I18n.tr("ADAPTER")
            SettingsControls.Row_ {
                label: I18n.tr("Wi-Fi")
                active: ShellState.hasWifi
                hint: I18n.tr("Turns the Wi-Fi radio on or off. Scanning only runs while this section is open.")
                SettingsControls.Switch_ { checked: ShellState.wifiOn; live: ShellState.hasWifi; onToggled: function(v) { ShellState.setWifi(v); } }
            }
            SettingsControls.Note_ {
                visible: !ShellState.hasWifi
                text: I18n.tr("This computer has no Wi-Fi adapter.")
            }
        }

        SettingsControls.Card_ {
            id: saved
            title: I18n.tr("SAVED NETWORKS")
            Repeater { model: ShellState.wifiOn ? ShellState.wifiNetworks.filter(function(n) { return n.known; }) : []; WifiRow {} }
            SettingsControls.Empty_ {
                visible: ShellState.wifiOn && ShellState.wifiNetworks.filter(function(n) { return n.known; }).length === 0
                icon: Icons.wifi; title: I18n.tr("No saved networks")
                body: I18n.tr("Saved Wi-Fi networks will appear here.")
            }
        }

        SettingsControls.Card_ {
            id: available
            title: I18n.tr("AVAILABLE")
            Repeater { model: ShellState.wifiOn ? ShellState.wifiNetworks.filter(function(n) { return !n.known; }) : []; WifiRow {} }
            SettingsControls.Empty_ {
                visible: ShellState.wifiOn && ShellState.wifiNetworks.length === 0
                icon: Icons.wifi; title: I18n.tr("Looking for networks")
                body: I18n.tr("Nearby networks appear here as NetworkManager finds them.")
            }
        }

        SettingsControls.Card_ {
            title: I18n.tr("ADVANCED")
            SettingsControls.Action_ {
                label: I18n.tr("Network profiles")
                hint: I18n.tr("Opens NetworkManager’s full editor for IP addresses, DNS, routes, VPN and enterprise Wi-Fi.")
                icon: Icons.wifiLock
                value: I18n.tr("IP · DNS · VPN")
                onTriggered: ShellState.openNetworkProfiles()
            }
        }
    }

    component WifiRow: Rectangle {
        id: row
        required property var modelData
        readonly property string ssid: modelData.name || ""
        readonly property bool asking: root.askingFor === ssid
        readonly property bool secured: ShellState.isSecured(modelData)
        // Card_ counts only children that implement this settings-row contract.
        // Without it, a live Repeater can render networks but its parent hides
        // the entire card because it believes there are zero visible rows.
        readonly property bool isSettingsRow: true
        readonly property bool matches: true
        function recount() {
            let p = row.parent;
            while (p) { if (p.isSettingsCard) { p.recount(); return; } p = p.parent; }
        }
        Component.onCompleted: recount()
        Layout.fillWidth: true
        Layout.preferredHeight: asking ? 78 : 44
        radius: Appearance.radS
        color: modelData.connected ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.18) : ma.containsMouse ? Qt.rgba(1,1,1,0.07) : "transparent"

        Connections {
            target: row.modelData; ignoreUnknownSignals: true
            function onConnectionFailed(reason) { root.errorFor = row.ssid; root.askingFor = row.secured ? row.ssid : ""; }
            function onConnectedChanged() { if (row.modelData.connected) { root.askingFor = ""; root.errorFor = ""; root.passwordDraft = ""; } }
        }
        ColumnLayout {
            anchors { fill: parent; leftMargin: 12; rightMargin: 12; topMargin: 0; bottomMargin: 7 }
            spacing: 5
            RowLayout {
                Layout.fillWidth: true; Layout.preferredHeight: 44; spacing: 10
                Text { text: ShellState.wifiIconFor(row.modelData.signalStrength || 0); color: row.modelData.connected ? Colors.accent : "#9a9a9a"; font.family: Appearance.font; font.pixelSize: 15 }
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 0
                    Text { Layout.fillWidth: true; text: row.ssid; color: "white"; elide: Text.ElideRight; font.family: Appearance.fontUI; font.pixelSize: Appearance.fsS }
                    Text { visible: text.length > 0; text: root.errorFor === row.ssid ? I18n.tr("Wrong password") : row.modelData.stateChanging ? I18n.tr("Connecting…") : row.modelData.connected ? I18n.tr("Connected") : row.modelData.known ? I18n.tr("Saved") : ""; color: root.errorFor === row.ssid ? Colors.crit : row.modelData.connected ? Colors.accent : "#7d7d7d"; font.family: Appearance.fontUI; font.pixelSize: Appearance.fsXS }
                }
                Text { visible: row.secured; text: Icons.lock; color: "#777"; font.family: Appearance.font; font.pixelSize: 11 }
                Text {
                    text: row.modelData.connected ? I18n.tr("Disconnect") : I18n.tr("Connect")
                    color: action.containsMouse ? Colors.accent : "#b0b0b0"; font.family: Appearance.fontUI; font.pixelSize: Appearance.fsXS
                    MouseArea { id: action; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: row.connectOrAsk() }
                }
                Text {
                    visible: row.modelData.known; text: "󰩹"; color: forget.containsMouse ? Colors.crit : "#7d7d7d"; font.family: Appearance.font; font.pixelSize: 13
                    MouseArea { id: forget; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { if (root.askingFor === row.ssid) root.askingFor = ""; row.modelData.forget(); } }
                }
            }
            TextField {
                id: password
                Layout.fillWidth: true; Layout.preferredHeight: 28; visible: row.asking
                echoMode: TextInput.Password; placeholderText: I18n.tr("Password"); color: "white"; placeholderTextColor: "#777"; selectionColor: Colors.accent
                font.family: Appearance.fontUI; font.pixelSize: Appearance.fsS
                text: row.asking ? root.passwordDraft : ""
                background: Rectangle { radius: Appearance.radS; color: Qt.rgba(0,0,0,0.4); border.width: 1; border.color: password.activeFocus ? Colors.accent : "#2a2a2a" }
                onVisibleChanged: if (visible) focusTimer.restart()
                onTextEdited: root.passwordDraft = text
                Keys.onReturnPressed: row.submit()
                Keys.onEnterPressed: row.submit()
            }
        }
        Timer { id: focusTimer; interval: 0; onTriggered: if (row.asking) password.forceActiveFocus() }
        function connectOrAsk() {
            root.errorFor = "";
            if (modelData.connected) { modelData.disconnect(); return; }
            if (modelData.known || !secured) modelData.connect();
            else { root.askingFor = ssid; root.passwordDraft = ""; }
        }
        function submit() { modelData.connectWithPsk(root.passwordDraft); root.askingFor = ""; }
        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; z: -1; onClicked: row.connectOrAsk() }
    }
}
