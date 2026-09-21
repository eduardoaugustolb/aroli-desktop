// LockSurface.qml — one lock surface per screen.
//
// Thin protocol wrapper around LockStage (the visuals, shared with the test
// harness). Owns the PAM lifecycle: only the primary screen drives the
// shared conversation; the others mirror the state.
import Quickshell
import Quickshell.Wayland
import QtQuick

WlSessionLockSurface {
    id: root

    required property var lock
    required property var pam
    required property string primaryScreen

    readonly property bool primary: screen !== null && screen.name === primaryScreen

    // Compositor facts, not the `locked` flag: on 0.3.1 `locked` can read
    // false with the session already locked (surface born with screen=null
    // size=0x0), so it must not gate the intro. `visible` + size always
    // arrive via proper notifies; own-property watchers always fire.
    readonly property bool shown: root.visible && root.width > 0 && root.height > 0
    onShownChanged: {
        root.dumpState("shown->" + root.shown);
        if (root.shown) {
            stage.playIntro();
            // begin() can lose the race when primary arrives before shown
            // (onPrimaryChanged requires shown). Never leave PAM unstarted.
            if (root.primary && !root.pam.active)
                root.pam.begin();
        } else {
            if (root.primary)
                root.pam.end();
            stage.playReset();
        }
    }
    // PAM starts once the primary screen is known AND mapped. `primary`
    // flips when `screen` arrives, which can lag behind `shown`.
    onPrimaryChanged: {
        if (root.primary && root.shown && !root.pam.active)
            root.pam.begin();
    }

    // Kept for the IPC/debug view; NOT a trigger (see above).
    readonly property bool isLocked: root.lock ? root.lock.locked : false

    color: "transparent"

    LockStage {
        id: stage
        // Explicit contentItem parenting (0.3.1 may not paint direct
        // children of WlSessionLockSurface). The warning about non-bindable
        // contentItem is benign: the object identity is stable, only its
        // size changes, which anchors track.
        parent: contentItem
        anchors.fill: parent
        pam: root.pam
        interactive: root.primary
        locked: root.shown
        onUnlockRequested: releaseTimer.restart()
    }

    // Release while the background is still ~80% faded (80+170ms fade,
    // release at 220ms): the desktop pops under a veil instead of after
    // full black. Snappier too.
    Timer {
        id: releaseTimer
        interval: 220
        onTriggered: {
            console.log("[aroli-lock] releasing lock");
            root.lock.locked = false;
        }
    }

    function dumpState(tag) {
        console.log("[aroli-lock]", tag,
            "screen=" + (screen ? screen.name : "null"),
            "size=" + width + "x" + height,
            "primary=" + root.primary,
            "isLocked=" + root.isLocked,
            "contentItem=" + (contentItem ? (contentItem.width + "x" + contentItem.height) : "null"));
    }

    Component.onCompleted: {
        root.dumpState("created");
        if (root.shown) {
            stage.playIntro();
            if (root.primary && !root.pam.active)
                root.pam.begin();
        }
    }
}
