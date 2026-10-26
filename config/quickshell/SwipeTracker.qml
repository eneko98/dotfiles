// A two-finger gesture tracker over a MouseArea. WheelHandler does not fire in
// this Wayland stack, so the wheel events are read from MouseArea.onWheel.
//
// It accumulates pixelDelta, locks to an axis after `axisLock` px, and on
// release (idleMs without events) decides: a swipe past the threshold or a
// fast flick emits `swiped(direction, velocity)`; anything else emits
// `released(axis)`. Mouse wheels (angleDelta without pixelDelta) are reported
// through `wheeled(direction)` and never count as swipes.
//
// It is not visual: put it over the area, anchored to fill.
import QtQuick

Item {
    id: root

    property real threshold: 0.35          // fraction of the area width
    property real velocityThreshold: 0.6   // px/ms
    property int axisLock: 8               // px before the axis is decided
    property int idleMs: 90
    property int sampleMs: 80

    // The axis the gesture locked to ("" until decided).
    property string axis: ""
    property real offset: 0

    property real _accX: 0
    property real _accY: 0
    property real _sumY: 0
    property var _samples: []

    signal swiped(string direction, real velocity)
    signal released(string axis)
    signal wheeled(string direction)

    function reset() {
        root.axis = "";
        root.offset = 0;
        root._accX = 0;
        root._accY = 0;
        root._sumY = 0;
        root._samples = [];
    }

    function velocity() {
        if (root._samples.length < 2)
            return 0;
        const first = root._samples[0];
        const last = root._samples[root._samples.length - 1];
        const dt = last.t - first.t;
        if (dt <= 0)
            return 0;
        return (last.dx - first.dx) / dt;
    }

    function release() {
        if (root.axis === "") {
            root.reset();
            return;
        }
        if (root.axis === "x") {
            const v = root.velocity();
            const width = root.width;
            if (Math.abs(root.offset) > width * root.threshold
                || Math.abs(v) > root.velocityThreshold) {
                root.swiped(root.offset < 0 || v < 0 ? "left" : "right", v);
            } else {
                root.released("x");
            }
        } else {
            if (Math.abs(root._sumY) > 20)
                root.wheeled(root._sumY > 0 ? "down" : "up");
            root.released("y");
        }
        root.reset();
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton

        onWheel: function (event) {
            const noPixel = event.pixelDelta.x === 0 && event.pixelDelta.y === 0;

            // A real mouse wheel: discrete, vertical, used for navigation.
            if (noPixel) {
                if (event.angleDelta.y !== 0)
                    root.wheeled(event.angleDelta.y > 0 ? "up" : "down");
                return;
            }

            const dx = event.inverted ? event.pixelDelta.x : -event.pixelDelta.x;
            const dy = event.pixelDelta.y;

            if (root.axis === "") {
                root._accX += Math.abs(dx);
                root._accY += Math.abs(dy);
                if (root._accX + root._accY < root.axisLock) {
                    idle.restart();
                    return;
                }
                root.axis = root._accX >= root._accY ? "x" : "y";
            }

            if (root.axis === "y") {
                root._sumY += dy;
                event.accepted = false;
                idle.restart();
                return;
            }

            root.offset += dx;
            root._samples = root._samples.concat([{ t: Date.now(), dx: root.offset }])
                .slice(-8);
            idle.restart();
        }
    }

    Timer {
        id: idle
        interval: root.idleMs
        onTriggered: root.release()
    }
}
