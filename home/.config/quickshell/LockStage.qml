// LockStage.qml - the lock screen visuals without the session-lock protocol.
//
// LockSurface (WlSessionLockSurface) embeds this for the real session; the
// visual test harness embeds it in a plain window. Single source of truth:
// any pixel difference between test and session is a bug, not a drift.
//
// A single floating card, Caelestia-placed and Aroli-dressed: stable dark
// surface, wallpaper only as blurred mood behind it, one accent tab keeping
// the threshold DNA. The card is the whole dialog - nothing floats outside
// it, so multi-monitor and fractional scales cannot strand content.
import Quickshell
import QtQuick
import QtQuick.Effects

Item {
    id: root

    required property var pam
    property bool interactive: false
    property bool locked: false

    signal unlockRequested()

    property bool unlocking: false
    property real bgOpacity: 0
    property real cardOpacity: 0
    property real cardScale: Appearance.mScaleFrom

    // Solid base FIRST (bottom): worst case is a dark screen, never a
    // transparent one (the compositor filler behind a transparent lock
    // surface reads as flat gray). Wallpaper goes above it, veil on top.
    Rectangle {
        anchors.fill: parent
        color: Colors.bg
        opacity: root.bgOpacity
    }
    // Background wallpaper, blurred + dimmed.
    Image {
        id: wall
        anchors.fill: parent
        source: Colors.wallpaper
        visible: source !== ""
        fillMode: Image.PreserveAspectCrop
        opacity: root.bgOpacity
        layer.enabled: true
        layer.effect: MultiEffect {
            autoPaddingEnabled: false
            blurEnabled: true
            blur: 1
            blurMax: 64
            blurMultiplier: 1
        }
    }
    // Fallback when no wallpaper is set yet + the dim veil.
    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: root.bgOpacity * 0.42
    }

    // ── THE CARD ──
    // Fixed width (content 382 + air), height wrapping the column: one
    // dialog, centered, floating over the mood. Grows from the badge morph
    // instead of popping with it (see playIntro sequencing below).
    Rectangle {
        id: card
        anchors.centerIn: parent
        implicitWidth: 430
        implicitHeight: center.contentHeight + 60
        radius: Appearance.radL
        color: Colors.bg
        border.width: 1
        border.color: Qt.rgba(Colors.fg.r, Colors.fg.g, Colors.fg.b, 0.09)
        opacity: root.cardOpacity
        scale: root.cardScale
        transformOrigin: Item.Center

        // Accent tab: the threshold survives as a 64 px handle, not a band.
        Rectangle {
            anchors.top: parent.top
            anchors.topMargin: 10
            anchors.horizontalCenter: parent.horizontalCenter
            width: 64
            height: 3
            radius: 2
            color: Colors.accent
        }

        LockCenter {
            id: center
            anchors.fill: parent
            anchors.topMargin: 30
            anchors.bottomMargin: 26
            anchors.leftMargin: 24
            anchors.rightMargin: 24
            pam: root.pam
            interactive: root.interactive
            armed: root.locked && !root.unlocking
            onOutroFinished: root.unlockRequested()
        }
    }

    Connections {
        target: root.pam
        function onAuthenticated() {
            if (!root.locked || root.unlocking)
                return;
            root.unlocking = true;
            // Sequenced exit: content morphs back first, the background
            // follows 120 ms later (180 ms fade), release lands at ~350 ms.
            // Fading everything at once - or releasing with bg painted -
            // reads as a cut, not a transition.
            center.playOutro();
            unlockFade.restart();
        }
    }

    Timer {
        id: unlockFade
        interval: 80
        onTriggered: fadeOut.start()
    }

    function playIntro() {
        root.unlocking = false;
        root.bgOpacity = 0;
        root.cardOpacity = 0;
        root.cardScale = Appearance.mScaleFrom;
        fadeOut.stop();
        introDelay.stop();
        // Background first: it is already mappable while the compositor
        // brings the surface up...
        fadeIn.start();
        center.reset();
        // ...the card + morph only after the first frames are actually
        // presenting, otherwise the springs settle invisibly and the badge
        // just pops in.
        introDelay.restart();
    }

    Timer {
        id: introDelay
        interval: 140
        onTriggered: {
            cardIn.start();
            center.playIntro();
        }
    }

    // The card grows around the badge morph: scale on a panel spring (no
    // cut on re-target), opacity on bezier with the usual stagger.
    ParallelAnimation {
        id: cardIn
        SpringAnimation {
            target: root; property: "cardScale"; to: 1
            spring: Appearance.sprPanel; damping: Appearance.dmpPanel
            epsilon: Appearance.eppScale
        }
        SequentialAnimation {
            PauseAnimation { duration: Appearance.mStagger }
            NumberAnimation {
                target: root; property: "cardOpacity"; to: 1
                duration: Appearance.mIn; easing.type: Easing.OutCubic
            }
        }
    }

    function playReset() {
        fadeIn.stop();
        fadeOut.stop();
        cardIn.stop();
        introDelay.stop();
        unlockFade.stop();
        root.unlocking = false;
        root.bgOpacity = 0;
        root.cardOpacity = 0;
        root.cardScale = Appearance.mScaleFrom;
        center.reset();
    }

    ParallelAnimation {
        id: fadeIn
        NumberAnimation {
            target: root; property: "bgOpacity"; to: 1
            duration: Appearance.mInScale; easing.type: Easing.OutCubic
        }
    }
    ParallelAnimation {
        id: fadeOut
        NumberAnimation {
            target: root; property: "cardOpacity"; to: 0
            duration: Appearance.mOutScale; easing.type: Easing.InQuad
        }
        NumberAnimation {
            target: root; property: "bgOpacity"; to: 0
            duration: Appearance.mOutScale; easing.type: Easing.InQuad
        }
    }
}
