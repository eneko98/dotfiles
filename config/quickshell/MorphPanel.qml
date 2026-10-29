// Panel that grows out of its trigger and shrinks back into it (brief 5.3).
// The geometry is an interpolation between two rects: `from` (the trigger,
// in window coordinates) and `to` (the panel's final place); `t` is driven by
// the open/close animations. The Surface goes from the trigger's elevation
// (e2) to e3 past the halfway point, and the radius eases from the trigger's
// pill shape to the panel radius.
//
// The content fades in from 40% of the way (and fades out first on close) --
// it must be laid out at its final size (a fixed-width child), never at the
// interpolating one, or it would reflow during the morph. The clip hides the
// overflow while the shape grows.
//
// `fromRadius` below 0 means "no shape change": the panel then keeps the
// final radius for the whole run (popups without a trigger).
import QtQuick

Item {
    id: morph

    property rect from: Qt.rect(0, 0, 0, 0)
    property rect to: Qt.rect(0, 0, 400, 400)
    property real fromRadius: -1
    property int fromLevel: 2
    property bool open: false

    // Extra fill alpha for surfaces that need to read more solid than the
    // shared pill/card (the workspace overview). 0 keeps the old behaviour.
    property real extra: 0

    signal closed()

    // Popups without a trigger (launcher, picker, overview) fade/scale in place
    // instead of morphing out of a bar pill.
    transformOrigin: Item.Center
    scale: morph.fromRadius < 0 ? (morph.open ? 1 : 0.98) : 1
    Behavior on scale {
        NumberAnimation {
            duration: morph.open ? Motion.medium : Motion.fast
            easing.type: Easing.BezierSpline
            easing.bezierCurve: morph.open ? Motion.decel : Motion.accel
        }
    }

    transform: Translate {
        id: noTriggerLift
        y: morph.fromRadius < 0 ? (morph.open ? 0 : -6) : 0

        Behavior on y {
            NumberAnimation {
                duration: morph.open ? Motion.medium : Motion.fast
                easing.type: Easing.BezierSpline
                easing.bezierCurve: morph.open ? Motion.decel : Motion.accel
            }
        }
    }

    default property alias content: contentItem.data

    property real t: 0
    function lerp(a, b) {
        return a + (b - a) * t;
    }

    x: lerp(from.x, to.x)
    y: lerp(from.y, to.y)
    width: lerp(from.width, to.width)
    height: lerp(from.height, to.height)
    readonly property real radiusNow: lerp(
        fromRadius < 0 ? Tokens.radius.panel : fromRadius,
        Tokens.radius.panel)

    // Open: medium on the decel curve (the panel arrives). Close: base on the
    // accel curve (it returns to the trigger); `closed()` fires at the end,
    // or immediately when it was already closed.
    NumberAnimation {
        id: openAnim
        target: morph; property: "t"; to: 1
        duration: Motion.medium
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Motion.decel
    }
    SequentialAnimation {
        id: closeAnim
        PauseAnimation { duration: 60 }
        NumberAnimation {
            target: morph; property: "t"; to: 0
            duration: Motion.base
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.accel
        }
        onFinished: morph.closed()
    }

    onOpenChanged: {
        if (open) {
            closeAnim.stop();
            openAnim.start();
        } else {
            openAnim.stop();
            if (t > 0)
                closeAnim.start();
            else
                morph.closed();
        }
    }

    Surface {
        anchors.fill: parent
        level: morph.t > 0.5 ? 3 : morph.fromLevel
        radius: morph.radiusNow
        extra: morph.extra
    }

    Item {
        id: contentItem
        anchors.fill: parent
        anchors.margins: Tokens.space.l
        clip: true
        opacity: morph.open ? Math.max(0, (morph.t - 0.4) / 0.6)
                            : Math.max(0, (morph.t - 0.6) / 0.4)

        property real shiftY: morph.open ? 0 : 8
        transform: Translate { id: contentShift; y: contentItem.shiftY }
        Behavior on shiftY {
            SequentialAnimation {
                PauseAnimation { duration: morph.open ? Math.round(Motion.medium * 0.4) : 0 }
                NumberAnimation {
                    duration: morph.open ? Motion.base : 0
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Motion.decel
                }
            }
        }
    }
}
