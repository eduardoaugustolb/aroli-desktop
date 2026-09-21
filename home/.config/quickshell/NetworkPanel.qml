// NetworkPanel.qml, network picker, unfolded FROM the notch.
//
// Replaces the rofi menu (~/.config/rofi/scripts/network-menu.sh). Talks
// directly to NetworkManager via Quickshell.Networking. Only WPA-Enterprise
// profiles jump to the official editor: Quickshell does not yet expose
// identity, EAP method, or certificates. The scanner only runs with this panel
// open.
import Quickshell
import Quickshell.Networking
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    // The same network UI lives in the transient notch and in Settings. In
    // Settings it must keep scanning, but Escape must remain owned by the
    // settings window rather than closing an unrelated notch panel.
    property bool settingsMode: false
    readonly property bool active: settingsMode
        ? (ShellState.settingsOpen && root.visible)
        : ShellState.panel === "network"
    // SSID whose row is unfolded asking for a password
    property string askingFor: ""
    property string errorFor: ""
    // NetworkManager refreshes/reorders the live model while scanning. A
    // delegate-local TextField is destroyed during that refresh, so the draft
    // must belong to the panel, not the row instance.
    property string passwordFor: ""
    property string passwordDraft: ""

    onActiveChanged: {
        if (root.active) keys.forceActiveFocus();
        else { root.askingFor = ""; root.errorFor = ""; root.passwordFor = ""; root.passwordDraft = ""; }
    }

    MouseArea { anchors.fill: parent }

    // Without this the panel was a mousetrap: the layer grabs the keyboard
    // exclusively (the password field needs it) but nothing handled keys, so
    // Escape never closed and nothing could be typed in any other window.
    Item {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: function (e) {
            if (root.askingFor !== "") { root.askingFor = ""; root.errorFor = ""; root.passwordFor = ""; root.passwordDraft = ""; }
            else if (!root.settingsMode) ShellState.closePanel();
            else return;
            e.accepted = true;
        }
        Keys.onDownPressed: if (list.count > 0) list.currentIndex = Math.min(list.count - 1, list.currentIndex + 1)
        Keys.onUpPressed: if (list.count > 0) list.currentIndex = Math.max(0, list.currentIndex - 1)
        Keys.onReturnPressed: list.activateCurrent()
        Keys.onEnterPressed: list.activateCurrent()
    }

    ColumnLayout {
        anchors { fill: parent; leftMargin: 22; rightMargin: 20; topMargin: 20; bottomMargin: 18 }
        spacing: 12

        // ─────────────── header ───────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                text: ShellState.netIcon
                color: ShellState.online ? Colors.accent : "#7d7d7d"
                font.family: Appearance.font; font.pixelSize: 18
            }
            ColumnLayout {
                spacing: 0
                Text {
                    text: I18n.tr("Network")
                    color: "#ffffff"
                    font.family: Appearance.fontUI; font.pixelSize: 13; font.weight: Font.DemiBold
                }
                Text {
                    // "Wi-Fi off" only when there is a radio to TURN ON.
                    // On a box with no adapter that sentence invites hunting for
                    // the switch that fixes it, and none exists.
                    text: ShellState.wiredDev ? I18n.tr("Cable connected")
                        : ShellState.wifiNet ? ShellState.wifiNet.name
                        : (ShellState.wifiOn || !ShellState.hasWifi) ? I18n.tr("Not connected") : I18n.tr("Wi-Fi off")
                    color: "#8a8a8a"
                    font.family: Appearance.fontUI; font.pixelSize: 11
                }
            }
            Item { Layout.fillWidth: true }

            // wifi switch, only with a radio to turn on
            Rectangle {
                visible: ShellState.hasWifi
                implicitWidth: 42; implicitHeight: 23
                radius: 12
                color: ShellState.wifiOn ? Colors.accent : Qt.rgba(1, 1, 1, 0.14)
                Behavior on color { ColorAnimation { duration: Appearance.mQuick; easing.type: Easing.OutQuad } }
                Rectangle {
                    width: 17; height: 17; radius: 9
                    color: "#ffffff"
                    y: 3
                    x: ShellState.wifiOn ? parent.width - width - 3 : 3
                    Behavior on x { NumberAnimation { duration: Appearance.mQuick; easing.type: Easing.OutCubic } }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ShellState.toggleWifi()
                }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: "#1e1e1e" }

        // ─────────────── network list ───────────────
        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 4
            model: ShellState.wifiOn ? ShellState.wifiNetworks : []
            currentIndex: -1
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded; width: 4 }

            // Enter on the keyboard-marked network
            function activateCurrent() {
                const n = list.model[list.currentIndex];
                if (!n || n.connected) return;
                root.errorFor = "";
                if (n.known || !ShellState.isSecured(n)) n.connect();
                else if (ShellState.isEnterprise(n)) ShellState.editEnterprise(n);
                else { root.askingFor = n.name || ""; root.passwordFor = root.askingFor; root.passwordDraft = ""; }
            }

            delegate: Rectangle {
                id: netRow
                required property var modelData
                required property int index

                readonly property string ssid: modelData.name || ""
                readonly property bool asking: root.askingFor === netRow.ssid
                readonly property bool secured: ShellState.isSecured(modelData)
                readonly property bool enterprise: ShellState.isEnterprise(modelData)

                width: list.width
                height: netRow.asking ? 88 : 44
                Behavior on height { NumberAnimation { duration: Appearance.mIn; easing.type: Easing.OutCubic } }
                radius: 12
                clip: true
                color: modelData.connected ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.18)
                     : (netMa.containsMouse || netRow.asking || netRow.index === list.currentIndex) ? Qt.rgba(1, 1, 1, 0.08)
                     : Qt.rgba(1, 1, 1, 0.04)
                Behavior on color { ColorAnimation { duration: Appearance.mQuick; easing.type: Easing.OutQuad } }

                Connections {
                    target: netRow.modelData
                    ignoreUnknownSignals: true
                    function onConnectionFailed(reason) {
                        root.errorFor = netRow.ssid;
                        root.askingFor = netRow.secured && !netRow.enterprise ? netRow.ssid : "";
                        if (root.askingFor !== "") root.passwordFor = netRow.ssid;
                    }
                    function onConnectedChanged() {
                        if (netRow.modelData.connected) { root.askingFor = ""; root.errorFor = ""; }
                    }
                }

                ColumnLayout {
                    anchors { fill: parent; leftMargin: 13; rightMargin: 12; topMargin: 0; bottomMargin: 8 }
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        spacing: 11

                        Text {
                            text: ShellState.wifiIconFor(netRow.modelData.signalStrength || 0)
                            color: netRow.modelData.connected ? Colors.accent : "#cfcfcf"
                            font.family: Appearance.font; font.pixelSize: 15
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Text {
                                Layout.fillWidth: true
                                text: netRow.ssid
                                color: "#ffffff"; elide: Text.ElideRight
                                font.family: Appearance.fontUI; font.pixelSize: 12
                                font.weight: netRow.modelData.connected ? Font.DemiBold : Font.Normal
                            }
                            Text {
                                Layout.fillWidth: true
                                visible: text.length > 0
                                text: root.errorFor === netRow.ssid
                                    ? (netRow.enterprise ? I18n.tr("Check the enterprise profile") : I18n.tr("Wrong password"))
                                    : netRow.modelData.stateChanging ? I18n.tr("Connecting…")
                                    : netRow.modelData.connected ? (netRow.enterprise ? I18n.tr("Connected · Enterprise") : I18n.tr("Connected"))
                                    : netRow.modelData.known ? (netRow.enterprise ? I18n.tr("Enterprise · Saved") : I18n.tr("Saved"))
                                    : netRow.enterprise ? I18n.tr("Enterprise · EAP") : ""
                                color: root.errorFor === netRow.ssid ? Colors.crit
                                     : netRow.modelData.connected ? Colors.accent : "#7d7d7d"
                                elide: Text.ElideRight
                                font.family: Appearance.fontUI; font.pixelSize: 10
                            }
                        }

                        Text {
                            visible: netRow.secured
                            text: netRow.enterprise ? Icons.wifiLock : Icons.lock
                            color: netRow.enterprise ? "#9a9a9a" : "#6f6f6f"
                            font.family: Appearance.font; font.pixelSize: 11
                        }

                        // EAP never fits safely in a password field:
                        // opens the exact profile for identity, method, and CA.
                        Text {
                            visible: netRow.enterprise
                            text: Icons.edit
                            color: editMa.containsMouse ? Colors.accent : "#777777"
                            font.family: Appearance.font; font.pixelSize: 12
                            MouseArea {
                                id: editMa
                                anchors.fill: parent; anchors.margins: -6
                                hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: ShellState.editEnterprise(netRow.modelData)
                            }
                        }

                        // disconnect / forget
                        Text {
                            visible: netMa.containsMouse && netRow.modelData.connected
                            text: "󰅖"
                            color: discMa.containsMouse ? Colors.crit : "#8a8a8a"
                            font.family: Appearance.font; font.pixelSize: 13
                            MouseArea {
                                id: discMa
                                anchors.fill: parent; anchors.margins: -6
                                hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: netRow.modelData.disconnect()
                            }
                        }

                        // Forget is explicit in both the quick picker and the
                        // Settings section. It applies to saved profiles even
                        // when they are not currently connected.
                        Text {
                            visible: netMa.containsMouse && netRow.modelData.known
                            text: "󰩹"
                            color: forgetMa.containsMouse ? Colors.crit : "#8a8a8a"
                            font.family: Appearance.font; font.pixelSize: 13
                            MouseArea {
                                id: forgetMa
                                anchors.fill: parent; anchors.margins: -6
                                hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root.askingFor === netRow.ssid) {
                                        root.askingFor = ""; root.passwordFor = ""; root.passwordDraft = "";
                                    }
                                    netRow.modelData.forget();
                                }
                            }
                        }
                    }

                    // ---- password, unfolded in the row itself ----
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 30
                        visible: netRow.asking
                        spacing: 8

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 30
                            radius: 9
                            color: Qt.rgba(0, 0, 0, 0.45)
                            border.width: 1
                            border.color: pskField.activeFocus ? Colors.accent : "#2a2a2a"
                            Behavior on border.color { ColorAnimation { duration: Appearance.mQuick; easing.type: Easing.OutQuad } }

                            TextField {
                                id: pskField
                                anchors { fill: parent; leftMargin: 11; rightMargin: 11 }
                                echoMode: TextInput.Password
                                placeholderText: I18n.tr("Password")
                                color: "#ffffff"
                                placeholderTextColor: "#5e5e5e"
                                selectionColor: Colors.accent
                                font.family: Appearance.fontUI; font.pixelSize: 12
                                background: null
                                padding: 0
                                verticalAlignment: TextInput.AlignVCenter
                                text: root.passwordFor === netRow.ssid ? root.passwordDraft : ""

                                // A recreated delegate rehydrates this field
                                // from root.passwordDraft, then regains focus
                                // on the next event turn after ListView settles.
                                onVisibleChanged: if (visible) inputRefocus.restart()
                                onTextEdited: root.passwordDraft = text
                                Keys.onEscapePressed: { root.askingFor = ""; root.errorFor = ""; root.passwordFor = ""; root.passwordDraft = ""; }
                                Keys.onReturnPressed: netRow.tryConnect()
                                Keys.onEnterPressed: netRow.tryConnect()
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: 74; Layout.preferredHeight: 30
                            radius: 9
                            color: okMa.containsMouse ? Colors.accent : Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.28)
                            Behavior on color { ColorAnimation { duration: Appearance.mQuick; easing.type: Easing.OutQuad } }
                            Text {
                                anchors.centerIn: parent
                                text: I18n.tr("Connect")
                                color: okMa.containsMouse ? "#000000" : "#ffffff"
                                font.family: Appearance.fontUI; font.pixelSize: 11; font.weight: Font.Medium
                            }
                            MouseArea {
                                id: okMa
                                anchors.fill: parent
                                hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: netRow.tryConnect()
                            }
                        }
                    }
                }

                Timer {
                    id: inputRefocus
                    interval: 0
                    onTriggered: if (netRow.asking && pskField.visible) pskField.forceActiveFocus()
                }

                function tryConnect() {
                    root.errorFor = "";
                    if (netRow.enterprise && !netRow.modelData.known) {
                        ShellState.editEnterprise(netRow.modelData);
                    } else if (netRow.secured && !netRow.modelData.known) netRow.modelData.connectWithPsk(root.passwordDraft);
                    else netRow.modelData.connect();
                    root.askingFor = "";
                }

                MouseArea {
                    id: netMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    z: -1
                    onClicked: {
                        if (netRow.modelData.connected) return;
                        root.errorFor = "";
                        // Saved or open -> straight in; EAP -> safe editor;
                        // only a new PSK network unfolds a key field.
                        if (netRow.modelData.known || !netRow.secured) netRow.modelData.connect();
                        else if (netRow.enterprise) ShellState.editEnterprise(netRow.modelData);
                        else if (netRow.asking) {
                            root.askingFor = ""; root.passwordFor = ""; root.passwordDraft = "";
                        } else {
                            root.askingFor = netRow.ssid; root.passwordFor = netRow.ssid; root.passwordDraft = "";
                        }
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !ShellState.wifiOn || ShellState.wifiNetworks.length === 0
            // With no adapter the list is empty FOREVER, so saying
            // "Scanning for networks…" would be a wait that never ends.
            text: !ShellState.hasWifi ? (ShellState.wiredDev ? I18n.tr("This computer uses a cable") : I18n.tr("This computer has no Wi-Fi"))
                : !ShellState.wifiOn ? I18n.tr("Wi-Fi off") : I18n.tr("Looking for networks…")
            color: "#5e5e5e"
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            font.family: Appearance.fontUI; font.pixelSize: 12
        }
    }
}
