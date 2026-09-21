// NotchLayer.qml, one notch "face" (resting, hover, OSD, panel...).
//
// This decides how EVERYTHING living inside the notch enters and leaves: eleven
// faces all pass through this file. Changing this changes the whole shell.
//
// Two ideas, and neither is "a prettier curve":
//
// 1. THE FACE ENTERS FROM THE SIDE OF THE BUTTON THAT SUMMONS IT. The launcher
//    is born on the left because its button is on the left; the control, net,
//    bluetooth, and power panels are born on the right, where their icons sit.
//    Ambient stuff (clock, music, notifications) does not travel: it grows in
//    the center, because you did not call it from anywhere.
//    Since the notch CLIPS (clip in TopShell), content travels inside the
//    slot: you do not see it appear, you see it arrive.
//
// 2. SCALE AND TRAVEL RUN ON SPRINGS, not fixed duration. A spring keeps
//    velocity, so opening a panel while another is still leaving CONTINUES the
//    first motion instead of cutting it and starting over. That is exactly the
//    moment a shell gives itself away, and where it used to feel rubbery.
//
// Opacity stays on bezier on purpose: a spring on opacity would overshoot past
// 1 and flash. And it keeps the stagger (mStagger) that avoids the smear of two
// faces visible at once, the new starts entering once the old has left.
import QtQuick

Item {
    id: layer
    property bool active: false

    // -1 born on the left · 0 grows in the center · +1 born on the right
    property int origin: 0

    visible: opacity > 0.01
    transformOrigin: Item.Center

    opacity: active ? 1 : 0
    Behavior on opacity {
        SequentialAnimation {
            PauseAnimation { duration: layer.active ? Appearance.mStagger : 0 }
            NumberAnimation {
                duration: layer.active ? Appearance.mIn : Appearance.mOut
                easing.type: layer.active ? Easing.OutCubic : Easing.InQuad
            }
        }
    }

    scale: active ? 1 : Appearance.mScaleFrom
    Behavior on scale {
        SequentialAnimation {
            PauseAnimation { duration: layer.active ? Appearance.mStagger : 0 }
            SpringAnimation {
                spring: Appearance.sprPanel
                damping: Appearance.dmpPanel
                epsilon: Appearance.eppScale
            }
        }
    }

    // Lateral travel. On exit it returns toward its side, so a face leaves
    // the way it came: the gesture reads the same going and coming back.
    property real slide: active ? 0 : origin * Appearance.mTravel
    Behavior on slide {
        SequentialAnimation {
            PauseAnimation { duration: layer.active ? Appearance.mStagger : 0 }
            SpringAnimation {
                spring: Appearance.sprPanel
                damping: Appearance.dmpPanel
                epsilon: Appearance.eppPx
            }
        }
    }
    transform: Translate { x: layer.slide }
}
