// OverviewWindow.qml - ONE window inside the overview grid.
//
// It is a LIVE thumbnail (ScreencopyView), not an icon: the workspace map is
// only good for deciding if you know at a glance what sits on 4, and that
// needs seeing content, not the app name.
//
// Three non-obvious things:
//
// 1. POSITION COMES FROM HYPRLAND, NOT A LAYOUT. The window sits where it
//    truly is on its workspace (`at` and `size` from hyprctl clients, minus
//    the monitor origin and the reserved band, times scale). So a small
//    floating window looks small and off-center, just like on the real
//    workspace: the grid is a MAP, not a window list.
//
// 2. THE THUMBNAIL NEVER LEAVES ITS CELL, so the cell never needs to clip.
//    Clipping would force painting each window TWICE (one clipped copy inside
//    and one free copy to drag, since nothing can leave a box that clips it).
//    Tying position and size to the cell area needs a single copy, which is
//    also the one that flies when dragging.
//
// 3. constraintSize LIMITS THE CAPTURE. Without it, capturing ten 1908x1036
//    windows at full size to paint them at 267x145 burns the iGPU to throw
//    away 98% of pixels. With it, the compositor already delivers the size
//    about to paint.
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick

Item {
    id: tile

    // ─── data ───
    property var client: null       // `hyprctl clients` object (lastIpcObject)
    property var toplevel: null     // Wayland toplevel, the thumbnail source
    property var mon: null          // monitor's lastIpcObject
    property real sc: 0.14          // desktop -> cell scale
    property real cellW: 0
    property real cellH: 0
    property real offX: 0           // cell corner inside the grid
    property real offY: 0

    // ─── visual state ───
    property bool live: false       // capturing? only with the overview open
    property bool hovered: false
    property bool pressed: false
    property bool dragging: false

    // The window you would return to closing the overview right now. Not
    // `toplevel.activated`: while the overview is open keyboard focus sits on
    // the shell's own layer, so NO window is activated and the highlight would
    // vanish exactly when needed.
    // focusHistoryID === 0 is "the last one that held focus", which is what
    // this means and survives the grab.
    readonly property bool focused: !!(client && client.focusHistoryID === 0)

    property real radOut: 18        // grid outer-corner radius
    property real radIn: 10         // inner-corner radii
    property real radMin: 7         // radius of a window touching no edge
    property bool atL: false; property bool atR: false
    property bool atT: false; property bool atB: false

    // ── optimistic position ──
    // Hyprland takes ~100 ms to confirm a move. If the thumbnail waited for
    // confirmation, on drop it would jump back to the old spot then jump to
    // the new one. With this it stays where you left it, and the lie removes
    // itself once real data agrees (or after 700 ms, if the move never landed).
    property var posHint: null
    Timer { id: hintGuard; interval: 700; onTriggered: tile.posHint = null }
    function setHint(hx, hy) { tile.posHint = { x: hx, y: hy }; hintGuard.restart(); }
    onClientChanged: {
        if (!posHint || !client || !client.at) return;
        if (Math.abs(client.at[0] - posHint.x) <= 2 && Math.abs(client.at[1] - posHint.y) <= 2) {
            posHint = null;
            hintGuard.stop();
        }
    }

    readonly property var res: (mon && mon.reserved) ? mon.reserved : [0, 0, 0, 0]
    readonly property real monX: mon ? mon.x : 0
    readonly property real monY: mon ? mon.y : 0
    readonly property var at: posHint ? [posHint.x, posHint.y]
        : (client && client.at ? client.at : [monX + res[0], monY + res[1]])

    // Floors and ceilings in pixels. Floor, because a 200x100 dialog would
    // make a 28x14 thumbnail you can neither see nor click. Ceiling, because
    // it guarantees the window never leaves its cell (see note 2).
    readonly property real tw: Math.min(cellW, Math.max(34, (client && client.size ? client.size[0] : 240) * sc))
    readonly property real th: Math.min(cellH, Math.max(24, (client && client.size ? client.size[1] : 140) * sc))
    readonly property real initX: offX + Math.max(0, Math.min(cellW - tw, (at[0] - monX - res[0]) * sc))
    readonly property real initY: offY + Math.max(0, Math.min(cellH - th, (at[1] - monY - res[1]) * sc))

    // ── rounding is INHERITED from the edge it touches ──
    // A maximized window fills the cell: with its own small radius a black
    // halo would show in all four cell corners. Here, the closer to an edge,
    // the more it adopts THAT edge's radius; a few pixels away it returns to
    // its own. So the mosaic reads as one cut piece, not loose cards over a
    // background.
    readonly property real dL: Math.max(0, initX - offX)
    readonly property real dR: Math.max(0, cellW - (initX - offX) - tw)
    readonly property real dT: Math.max(0, initY - offY)
    readonly property real dB: Math.max(0, cellH - (initY - offY) - th)
    function corner(cA, cB, dA, dB_) {
        const base = (cA && cB) ? tile.radOut : tile.radIn;
        return Math.max(base - Math.max(dA, dB_), tile.radMin);
    }

    x: initX
    y: initY
    width: tw
    height: th

    // Restores position bindings on drop.
    function rebind() {
        tile.x = Qt.binding(() => tile.initX);
        tile.y = Qt.binding(() => tile.initY);
    }

    // And RELEASES them when dragging starts. This was the drag bug, and the
    // rebind() note had it exactly backwards: `drag.target` never moves the
    // thumbnail from QML, it moves it from C++ (QQuickItem::setX), and that
    // does NOT break the binding. The binding stayed alive, so every time
    // `initX` re-evaluated -on every mouse event- the thumbnail snapped back
    // to its cell, and both fought at 60 fps. Logged: x alternating between
    // 1100 (its place) and 2606, OUTSIDE the 1372 px-wide grid, i.e. off
    // screen.
    //
    // On camera that looked exactly as Eduardo Augusto described: the window never
    // drags, only the target cell lights, and on drop it appears there. With
    // bindings released, Qt stays out and the thumbnail sticks to the cursor,
    // which is what this wanted to show.
    function unbind() {
        const px = tile.x;
        const py = tile.y;
        tile.x = px;
        tile.y = py;
    }

    // While dragging, the thumbnail must stick TO the cursor: any
    // interpolation here reads as lag, not smoothness.
    Behavior on x { enabled: !tile.dragging; NumberAnimation { duration: Appearance.mIn; easing.type: Easing.OutCubic } }
    Behavior on y { enabled: !tile.dragging; NumberAnimation { duration: Appearance.mIn; easing.type: Easing.OutCubic } }
    Behavior on width { NumberAnimation { duration: Appearance.mIn; easing.type: Easing.OutCubic } }
    Behavior on height { NumberAnimation { duration: Appearance.mIn; easing.type: Easing.OutCubic } }

    // The lift on grab. Not decoration: it separates "dragging
    // this" from "mouse passing over". Spring-driven so on drop it settles
    // instead of cutting.
    property real lift: dragging ? 1.07 : (pressed ? 0.97 : 1)
    Behavior on lift { SpringAnimation { spring: Appearance.sprTight; damping: Appearance.dmpTight; epsilon: Appearance.eppScale } }
    scale: lift
    transformOrigin: Item.Center

    ClippingRectangle {
        anchors.fill: parent
        color: "#101010"
        antialiasing: true
        contentUnderBorder: true
        topLeftRadius: tile.corner(tile.atL, tile.atT, tile.dL, tile.dT)
        topRightRadius: tile.corner(tile.atR, tile.atT, tile.dR, tile.dT)
        bottomLeftRadius: tile.corner(tile.atL, tile.atB, tile.dL, tile.dB)
        bottomRightRadius: tile.corner(tile.atR, tile.atB, tile.dR, tile.dB)
        // The border says three different things, hence three colors, not three
        // widths: changing width would shift content a pixel, and with ten
        // thumbnails that reads as the whole grid shivering.
        border.width: 1
        border.color: tile.dragging ? Colors.accent
            : tile.hovered ? Qt.rgba(1, 1, 1, 0.45)
            : tile.focused ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.7)
            : Qt.rgba(1, 1, 1, 0.16)
        Behavior on border.color { ColorAnimation { duration: Appearance.mQuick } }

        ScreencopyView {
            id: shot
            anchors.fill: parent
            captureSource: tile.live ? tile.toplevel : null
            // Pixel-snapped: a fractional size would make the
            // compositor rescale the capture every frame.
            constraintSize: Qt.size(Math.max(1, Math.round(tile.width)), Math.max(1, Math.round(tile.height)))
            live: tile.live
        }

        // Fallback icon. A freshly opened window can take a while to produce
        // its first frame; without this the slot stays black, looking missing.
        Image {
            id: fallback
            readonly property real s: Math.max(20, Math.min(tile.width, tile.height) * 0.42)
            anchors.centerIn: parent
            visible: !shot.hasContent && source !== ""
            source: tile.iconSource
            width: s; height: s
            sourceSize: Qt.size(s, s)
            mipmap: true
            opacity: 0.9
        }

        // Status veil. Goes INSIDE the clip to respect the corners.
        Rectangle {
            anchors.fill: parent
            color: tile.dragging ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.14)
                : tile.hovered ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
            Behavior on color { ColorAnimation { duration: Appearance.mQuick } }
        }
    }

    readonly property string cls: client ? (client["class"] || client.initialClass || "") : ""
    readonly property string iconSource: {
        if (tile.cls.length === 0) return "";
        const entry = DesktopEntries.heuristicLookup(tile.cls);
        return Quickshell.iconPath(entry ? entry.icon : tile.cls.toLowerCase(), "application-x-executable");
    }
}
