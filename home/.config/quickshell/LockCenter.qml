// LockCenter.qml, the authentication column inside the floating card.
//
// Caelestia's idea (a morphing badge that becomes the auth surface) painted
// with Aroli rules. Every element justifies itself:
//
//   avatar   WHO is locked out. Lock icon morphs into face/initial so the
//            screen answers "whose password?" before asking for it. Click
//            focuses the password field.
//   time     Reassurance, not hero: tabular numerals, no layout shift.
//   date     Rice language, never the process locale.
//   pill     The ONLY raised surface (everything else sits on the card).
//            Accent border at rest, ok while checking, crit on failure:
//            state is color AND text, never color alone.
//   status   Attempt count + PAM errors. Fixed height: no reflow.
//   caps     Warning in warn tone: a wrong-password mystery is usually this.
//   user     Identity anchor (mono, like the bar). Click focuses password.
//   battery  Charge anchor. Click toggles % <-> time estimate.
//
// Motion follows Appearance (springs for shape/scale, bezier for opacity,
// mStagger between the old leaving and the new entering).
import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property var pam
    // Only the focused screen takes input; the others mirror the state.
    property bool interactive: false
    // True while the session is locked and no unlock animation runs.
    property bool armed: false

    signal outroFinished()

    readonly property string userName: Quickshell.env("USER")
    readonly property int contentW: 382
    // Exposed so the card wraps the column instead of guessing its height.
    readonly property int contentHeight: col.implicitHeight
    // Battery toggles % <-> estimate on click: glanceable by default,
    // precise on demand. Kept in the lock, not the shell: ShellState owns
    // the estimate text and both read the same source.
    property bool showEstimate: false

    // ── morph state ──
    property real avatarScale: 0
    property real avatarRotation: 180
    property real contentOpacity: 0
    property real badgePhase: 1
    property real inputW: 0
    property bool unlocking: false

    function reset() {
        outroAnim.stop();
        introAnim.stop();
        root.unlocking = false;
        root.avatarScale = 0;
        root.avatarRotation = 180;
        root.contentOpacity = 0;
        root.badgePhase = 1;
        root.inputW = 0;
    }

    function playIntro() {
        root.reset();
        introAnim.start();
    }

    function playOutro() {
        if (root.unlocking)
            return;
        root.unlocking = true;
        introAnim.stop();
        outroAnim.start();
    }

    function focusPassword() {
        if (root.interactive)
            pwdInput.forceActiveFocus();
    }

    SequentialAnimation {
        id: introAnim
        // 1. The badge arrives: scale on a loose spring, rotation fixed.
        ParallelAnimation {
            SpringAnimation {
                target: root; property: "avatarScale"; to: 1
                spring: Appearance.sprLoose; damping: Appearance.dmpLoose
                epsilon: Appearance.eppScale
            }
            NumberAnimation {
                target: root; property: "avatarRotation"; to: 360
                duration: Appearance.mShape; easing.type: Easing.OutCubic
            }
        }
        // 2. The badge becomes the avatar, the column fades in, the pill grows.
        ParallelAnimation {
            NumberAnimation {
                target: root; property: "badgePhase"; to: 0
                duration: Appearance.mIn; easing.type: Easing.OutCubic
            }
            SequentialAnimation {
                PauseAnimation { duration: Appearance.mStagger }
                NumberAnimation {
                    target: root; property: "contentOpacity"; to: 1
                    duration: Appearance.mIn; easing.type: Easing.OutCubic
                }
            }
            SpringAnimation {
                target: root; property: "inputW"; to: root.contentW
                spring: Appearance.sprPanel; damping: Appearance.dmpPanel
                epsilon: Appearance.eppPx
            }
        }
        onFinished: {
            if (root.interactive)
                pwdInput.forceActiveFocus();
        }
    }

    SequentialAnimation {
        id: outroAnim
        ParallelAnimation {
            NumberAnimation {
                target: root; property: "contentOpacity"; to: 0
                duration: Appearance.mOut; easing.type: Easing.InQuad
            }
            NumberAnimation {
                target: root; property: "inputW"; to: 0
                duration: Appearance.mOutShape; easing.type: Easing.InQuad
            }
        }
        ParallelAnimation {
            SpringAnimation {
                target: root; property: "avatarScale"; to: 0
                spring: Appearance.sprLoose; damping: Appearance.dmpLoose
                epsilon: Appearance.eppScale
            }
            NumberAnimation {
                target: root; property: "avatarRotation"; to: 540
                duration: Appearance.mOutShape; easing.type: Easing.InQuad
            }
        }
        onFinished: root.outroFinished()
    }

    ColumnLayout {
        id: col
        anchors.centerIn: parent
        spacing: 0

        // ── avatar / badge ──
        // Identity, not decoration: answers "whose password?" before asking.
        // Click focuses the field, the biggest target on the card.
        Item {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 72; implicitHeight: 72
            scale: root.avatarScale
            rotation: root.avatarRotation
            transformOrigin: Item.Center

            ClippingRectangle {
                anchors.fill: parent
                topLeftRadius: 36
                topRightRadius: 36
                bottomLeftRadius: 36
                bottomRightRadius: 36
                color: Colors.bgAlt
                border.width: 1
                border.color: Qt.rgba(Colors.fg.r, Colors.fg.g, Colors.fg.b, 0.12)

                Image {
                    id: face
                    anchors.fill: parent
                    source: "file://" + ShellState.home + "/.face"
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: 144
                    visible: status === Image.Ready
                    opacity: 1 - root.badgePhase
                }
                Text {
                    anchors.centerIn: parent
                    visible: face.status !== Image.Ready
                    text: root.userName.length > 0 ? root.userName.charAt(0).toUpperCase() : "?"
                    color: Colors.accent
                    font.family: Appearance.fontUI
                    font.pixelSize: 30
                    font.weight: Font.DemiBold
                    opacity: 1 - root.badgePhase * 0.5
                }
                Text {
                    anchors.centerIn: parent
                    text: Icons.lock
                    color: Colors.fg
                    font.family: Appearance.font
                    font.pixelSize: 26
                    opacity: root.badgePhase
                }
            }

            MouseArea {
                anchors.fill: parent
                enabled: root.interactive
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.focusPassword()
            }
        }

        // ── time ──
        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 12
            text: Qt.formatDateTime(ShellState.now, "HH:mm")
            color: Colors.fg
            font.family: Appearance.fontUI
            font.pixelSize: 38
            font.weight: Font.DemiBold
            font.features: ({ "tnum": 1 })
            opacity: root.contentOpacity
        }

        // ── date (rice language, never the process locale) ──
        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 2
            text: ShellState.capitalize(ShellState.now.toLocaleDateString(ShellState.loc, "dddd"))
                + " · " + ShellState.now.toLocaleDateString(ShellState.loc, I18n.tr("d MMMM"))
            color: Colors.dim
            font.family: Appearance.fontUI
            font.pixelSize: 12
            opacity: root.contentOpacity
        }

        // ── input pill: the only raised surface ──
        Rectangle {
            id: pill
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 14
            Layout.preferredWidth: Math.max(1, root.inputW)
            Layout.preferredHeight: 44
            radius: 22
            clip: true
            color: Colors.bgAlt
            border.width: 2
            border.color: root.pam && root.pam.checking ? Colors.ok
                : (root.pam && (root.pam.errorText.length > 0 || root.pam.attempts > 0) && root.pam.buffer.length === 0 ? Colors.crit : Colors.accent)
            opacity: root.contentOpacity
            Behavior on border.color { ColorAnimation { duration: Appearance.mQuick } }

            // Clicking anywhere on the pill focuses the field (the
            // placeholder label on top would otherwise eat the press).
            // Declared before the content row so the arrow button on top
            // keeps its own press.
            MouseArea {
                anchors.fill: parent
                enabled: root.interactive
                cursorShape: Qt.IBeamCursor
                onClicked: pwdInput.forceActiveFocus()
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 6
                spacing: 10

                Text {
                    id: lockGlyph
                    Layout.alignment: Qt.AlignVCenter
                    text: Icons.lock
                    color: root.pam && root.pam.checking ? Colors.ok
                        : (root.pam && root.pam.errorText.length > 0 ? Colors.crit : Colors.dim)
                    font.family: Appearance.font
                    font.pixelSize: 16
                    SequentialAnimation {
                        running: root.pam && root.pam.checking
                        loops: Animation.Infinite
                        NumberAnimation { target: lockGlyph; property: "opacity"; to: 0.35; duration: Appearance.mQuick }
                        NumberAnimation { target: lockGlyph; property: "opacity"; to: 1.0; duration: Appearance.mQuick }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    TextInput {
                        id: pwdInput
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        clip: true
                        enabled: root.interactive
                        echoMode: TextInput.Password
                        passwordCharacter: "●"
                        color: Colors.fg
                        selectionColor: Colors.accent
                        selectedTextColor: Colors.bg
                        font.family: Appearance.fontUI
                        font.pixelSize: 13
                        activeFocusOnPress: root.interactive
                        text: root.pam ? root.pam.buffer : ""
                        onTextChanged: {
                            if (root.pam && text !== root.pam.buffer)
                                root.pam.buffer = text;
                        }
                        onAccepted: { if (root.pam) root.pam.submit(); }
                        Keys.onReturnPressed: { if (root.pam) root.pam.submit(); }
                        Keys.onEnterPressed: { if (root.pam) root.pam.submit(); }
                        Keys.onEscapePressed: { if (root.pam) root.pam.buffer = ""; }
                        onActiveFocusChanged: {
                            if (!activeFocus && root.armed && root.interactive)
                                focusTimer.restart();
                        }
                    }
                    Timer {
                        id: focusTimer
                        interval: 120
                        onTriggered: {
                            if (root.armed && root.interactive)
                                pwdInput.forceActiveFocus();
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: pwdInput.text.length === 0
                        text: I18n.tr("Enter your password")
                        color: Qt.rgba(Colors.fg.r, Colors.fg.g, Colors.fg.b, 0.55)
                        font.family: Appearance.fontUI
                        font.pixelSize: 13
                    }
                }

                Rectangle {
                    id: goBtn
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: 32; implicitHeight: 32
                    radius: 16
                    color: pwdInput.text.length > 0 ? Colors.accent : Qt.rgba(Colors.fg.r, Colors.fg.g, Colors.fg.b, 0.10)
                    Behavior on color { ColorAnimation { duration: Appearance.mQuick } }
                    Text {
                        anchors.centerIn: parent
                        text: "→"
                        color: pwdInput.text.length > 0 ? Colors.bg : Colors.dim
                        font.family: Appearance.fontUI
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                    }
                    MouseArea {
                        anchors.fill: parent
                        enabled: root.interactive
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { if (root.pam) root.pam.submit(); }
                    }
                }
            }
        }

        // ── status + caps/num warning (fixed height: no reflow) ──
        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 8
            implicitWidth: root.contentW
            implicitHeight: 34
            opacity: root.contentOpacity

            Text {
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.pam ? root.pam.statusText() : ""
                visible: text.length > 0
                color: root.pam && root.pam.checking ? Colors.ok : Colors.crit
                font.family: Appearance.fontUI
                font.pixelSize: 12
                font.weight: Font.Medium
            }
            Text {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.pam ? root.pam.warnText() : ""
                visible: text.length > 0
                color: Colors.warn
                font.family: Appearance.fontUI
                font.pixelSize: 11
                font.weight: Font.Medium
            }
        }

        // ── fingerprint hint ──
        Text {
            Layout.alignment: Qt.AlignHCenter
            visible: root.pam && root.pam.fprintEnrolled && root.pam.attempts === 0 && !root.pam.checking
            text: I18n.tr("or touch the fingerprint reader")
            color: Colors.dim
            font.family: Appearance.fontUI
            font.pixelSize: 11
            opacity: root.contentOpacity
        }

        // ── identity + battery anchoring the ends ──
        // Both ends earn their pixels: user confirms WHO (click focuses the
        // field), battery answers HOW MUCH (click toggles % <-> estimate).
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 10
            implicitWidth: root.contentW
            opacity: root.contentOpacity

            Text {
                Layout.alignment: Qt.AlignVCenter
                text: root.userName
                color: Colors.dim
                font.family: Appearance.font
                font.pixelSize: 12

                MouseArea {
                    anchors.fill: parent
                    enabled: root.interactive
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.focusPassword()
                }
            }
            Item { Layout.fillWidth: true }
            Text {
                Layout.alignment: Qt.AlignVCenter
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
                visible: ShellState.batt >= 0
                text: root.showEstimate ? ShellState.battEstimateText
                    : ShellState.battIcon + "  " + ShellState.batt + "%"
                color: root.showEstimate ? Colors.accent : Colors.dim
                font.family: Appearance.font
                font.pixelSize: 12
                Behavior on color { ColorAnimation { duration: Appearance.mQuick } }

                MouseArea {
                    anchors.fill: parent
                    enabled: root.interactive
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.showEstimate = !root.showEstimate
                }
            }
        }
    }
}
