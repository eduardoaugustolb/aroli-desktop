// HistoryGraph.qml - compact time curve for floor..ceiling metrics.
// Canvas is used here on purpose: a series changing every 1.5 s does not
// deserve sixty Rectangles or a delegate model. Fill, floor, and live dot come
// from the same geometry, so they never drift apart.
//
// MARK SPEC (not taste, the measurements that make a chart read calm instead
// of shouting):
//   · 2 px stroke, with round joins and caps;
//   · area fill at ~10% of the hue - a veil, NEVER a saturated block.
//     It sat at 24% and that is why the memory band looked like a brick: a
//     big opaque fill is what separates a chart from a poster;
//   · 8 px end dot (r 4) - below that it is not a mark, it is a speck;
//   · 2 px SURFACE ring around the dot, so it reads where it crosses its own
//     line. Done by punching the hole (destination-out) instead of painting a
//     border: a border is ink that is not data, and here it would not even
//     work because the card is translucent and there is no background color to
//     copy;
//   · grid and floor, SOLID 1 px hairline. No dashes: dashing adds noise and
//     reads as "threshold" or "projection" when it is only a grid.
import QtQuick

Canvas {
    id: root

    property var values: []
    property real floor: 0
    property real ceiling: 100
    property color lineColor: Colors.accent
    property color fillTop: Qt.rgba(lineColor.r, lineColor.g, lineColor.b, 0.10)
    property color fillBottom: Qt.rgba(lineColor.r, lineColor.g, lineColor.b, 0.004)
    property color gridColor: Qt.rgba(1, 1, 1, 0.075)
    property bool showGrid: true
    property bool showBaseline: false
    property bool showPoint: true

    // Fraction of the width the series fades in over (0 = none).
    // The left end is past falling off the history: cut to the bone, the curve
    // looks amputated against the card edge and the eye goes right there.
    // Faded, the band has no beginning and the gaze drifts on its own to the
    // side that matters, the "now" side.
    property real fadeIn: 0

    // Sample under the pointer, or -1. The cross is painted by Canvas itself
    // because it must land EXACTLY on the sample: a Rectangle placed from
    // outside would have to reproduce the same coordinate math here, and two
    // copies of one formula end up drifting apart.
    property int markIndex: -1

    antialiasing: true

    onValuesChanged: requestPaint()
    onMarkIndexChanged: requestPaint()
    onShowBaselineChanged: requestPaint()
    onShowGridChanged: requestPaint()
    onShowPointChanged: requestPaint()
    onFadeInChanged: requestPaint()
    onFloorChanged: requestPaint()
    onCeilingChanged: requestPaint()
    onLineColorChanged: requestPaint()
    onFillTopChanged: requestPaint()
    onFillBottomChanged: requestPaint()
    onGridColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    Component.onCompleted: requestPaint()

    function trace(ctx, pts) {
        if (pts.length === 0) return;
        ctx.moveTo(pts[0].x, pts[0].y);
        if (pts.length === 1) return;
        for (let i = 1; i < pts.length - 1; i++) {
            const mx = (pts[i].x + pts[i + 1].x) / 2;
            const my = (pts[i].y + pts[i + 1].y) / 2;
            ctx.quadraticCurveTo(pts[i].x, pts[i].y, mx, my);
        }
        const last = pts[pts.length - 1];
        ctx.quadraticCurveTo(last.x, last.y, last.x, last.y);
    }

    onPaint: {
        const ctx = getContext("2d");
        ctx.clearRect(0, 0, width, height);
        if (width < 2 || height < 2) return;

        // 7 px of air top and bottom: the live dot radius (4) plus its
        // ring (2), or the dot clips against the edge when the series
        // touches ceiling or floor.
        const top = 7, bottom = height - 7;
        const graphH = Math.max(1, bottom - top);

        // Solid 1 px hairline, one step above the surface. I had it dashed
        // for a while because it "competed less with the curve"; it is the
        // reverse: dashing adds noise and on top means something else
        // (threshold, projection). What keeps the grid from competing is being
        // faint, not being broken.
        if (root.showGrid) {
            ctx.lineWidth = 1;
            ctx.strokeStyle = root.gridColor;
            for (let i = 1; i <= 3; i++) {
                const gy = top + graphH * i / 4;
                ctx.beginPath();
                ctx.moveTo(0, Math.round(gy) + 0.5);
                ctx.lineTo(width, Math.round(gy) + 0.5);
                ctx.stroke();
            }
        }

        // The floor. Without it the area cuts off into the void and the card
        // has nothing to rest on; with it the curve rests on something.
        if (root.showBaseline) {
            ctx.lineWidth = 1;
            ctx.strokeStyle = root.gridColor;
            ctx.beginPath();
            ctx.moveTo(0, Math.round(bottom) + 0.5);
            ctx.lineTo(width, Math.round(bottom) + 0.5);
            ctx.stroke();
        }

        let raw = root.values && root.values.length ? root.values : [0];
        const vals = raw.length === 1 ? [raw[0], raw[0]] : raw;
        const span = Math.max(0.001, root.ceiling - root.floor);
        const pts = [];
        for (let i = 0; i < vals.length; i++) {
            const v = Math.max(root.floor, Math.min(root.ceiling, Number(vals[i]) || 0));
            pts.push({
                x: vals.length === 1 ? 0 : i * width / (vals.length - 1),
                y: bottom - ((v - root.floor) / span) * graphH
            });
        }

        // Area: more ink next to the signal, nearly transparent against the base.
        const gradient = ctx.createLinearGradient(0, top, 0, bottom);
        gradient.addColorStop(0, root.fillTop);
        gradient.addColorStop(1, root.fillBottom);
        ctx.beginPath();
        root.trace(ctx, pts);
        ctx.lineTo(pts[pts.length - 1].x, bottom);
        ctx.lineTo(pts[0].x, bottom);
        ctx.closePath();
        ctx.fillStyle = gradient;
        ctx.fill();

        ctx.beginPath();
        root.trace(ctx, pts);
        ctx.lineCap = "round";
        ctx.lineJoin = "round";
        ctx.lineWidth = 2;
        ctx.strokeStyle = root.lineColor;
        ctx.stroke();

        // One mark with its ring: punch (destination-out) the surface gap
        // and then set the dot inside. This used to be a halo of the hue
        // itself over an r 2.3 speck - that is, more series ink on top of the
        // series, exactly what the ring avoids.
        function dot(x, y) {
            ctx.globalCompositeOperation = "destination-out";
            ctx.beginPath();
            ctx.arc(x, y, 6, 0, Math.PI * 2);
            ctx.fillStyle = "rgba(0,0,0,1)";
            ctx.fill();
            ctx.globalCompositeOperation = "source-over";
            ctx.beginPath();
            ctx.arc(x, y, 4, 0, Math.PI * 2);
            ctx.fillStyle = root.lineColor;
            ctx.fill();
        }

        // The cross hunts the X: it snaps to the nearest sample, so it points
        // at an instant and not at a two-pixel line.
        const mi = root.markIndex;
        if (mi >= 0 && mi < pts.length) {
            const m = pts[mi];
            ctx.lineWidth = 1;
            ctx.strokeStyle = root.gridColor;
            ctx.beginPath();
            ctx.moveTo(Math.round(m.x) + 0.5, 0);
            ctx.lineTo(Math.round(m.x) + 0.5, height);
            ctx.stroke();
            dot(m.x, m.y);
        }

        // The "now" dot. Kept 4 px off the edge so its ring does not
        // leave the canvas.
        if (root.showPoint) {
            const p = pts[pts.length - 1];
            dot(p.x - 4, p.y);
        }

        // The fade goes LAST and eats everything painted before (grid,
        // floor, area, and stroke at once). With 'destination-out' the gradient
        // adds no ink: it removes alpha, so it works the same whatever color
        // sits under the card. Painting a background-colored gradient on top
        // would not do: the card is translucent and the patch would show.
        if (root.fadeIn > 0) {
            const edge = Math.max(1, width * root.fadeIn);
            const mask = ctx.createLinearGradient(0, 0, edge, 0);
            mask.addColorStop(0, "rgba(0,0,0,1)");
            mask.addColorStop(1, "rgba(0,0,0,0)");
            ctx.globalCompositeOperation = "destination-out";
            ctx.fillStyle = mask;
            ctx.fillRect(0, 0, edge, height);
            ctx.globalCompositeOperation = "source-over";
        }
    }
}
