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
    // shared pill/card. 0 keeps the old behaviour.
    property real extra: 0

    // A panel whose content floats (the workspace carousel) keeps the geometry
    // and the fade but paints no surface: there is no box behind the cards.
    property bool fill: true

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

    // Two clocks, like the reference: the panel first DROPS below the bar
    // (tMove) and then GROWS to its size (tSize). One rect interpolation made
    // the opening read as a single blur with no gesture in it.
    property real tMove: 0
    property real tSize: 0

    function lerp(a, b, t) {
        return a + (b - a) * t;
    }

    x: lerp(from.x, to.x, tMove)
    y: lerp(from.y, to.y, tMove)
    width: lerp(from.width, to.width, tSize)
    height: lerp(from.height, to.height, tSize)
    readonly property real radiusNow: lerp(
        fromRadius < 0 ? Tokens.radius.panel : fromRadius,
        Tokens.radius.panel, tSize)

    // Open: drop, then grow, each on a soft out-back so the panel settles with
    // a small overshoot. Close: shrink, then rise back into the pill.
    SequentialAnimation {
        id: openAnim

        NumberAnimation {
            target: morph; property: "tMove"; to: 1
            duration: Motion.panelDrop
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.backOut
        }
        NumberAnimation {
            target: morph; property: "tSize"; to: 1
            duration: Motion.panelGrow
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.backOut
        }
    }

    SequentialAnimation {
        id: closeAnim

        NumberAnimation {
            target: morph; property: "tSize"; to: 0
            duration: Motion.panelShrink
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.decel
        }
        NumberAnimation {
            target: morph; property: "tMove"; to: 0
            duration: Motion.panelRise
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.backOut
        }
        onFinished: morph.closed()
    }

    onOpenChanged: {
        if (open) {
            closeAnim.stop();
            openAnim.start();
        } else {
            openAnim.stop();
            if (tSize > 0 || tMove > 0)
                closeAnim.start();
            else
                morph.closed();
        }
    }

    Surface {
        anchors.fill: parent
        visible: morph.fill
        level: morph.tSize > 0.5 ? 3 : morph.fromLevel
        radius: morph.radiusNow
        extra: morph.extra
    }

    Item {
        id: contentItem
        anchors.fill: parent
        anchors.margins: Tokens.space.l
        clip: true
        // The content arrives late (the reference is sharp only at the very
        // end of the growth), so the surface reads as a pill stretching before
        // anything is written on it.
        opacity: morph.open ? Math.max(0, (morph.tSize - 0.55) / 0.45)
                            : Math.max(0, (morph.tSize - 0.7) / 0.3)

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
