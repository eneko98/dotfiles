// A ring gauge drawn with Shapes, the same technique the reference dots use
// (QtQuick.Shapes + PathAngleArc, no Canvas). The ring is open at the bottom:
// the track covers the whole circle except `gapAngle`, and the value arc grows
// from the same start.
import QtQuick
import QtQuick.Shapes

Item {
    id: root

    property real value: 0
    property color fillColor: Theme.gold
    property color trackColor: Qt.rgba(Theme.fg0.r, Theme.fg0.g, Theme.fg0.b, 0.09)
    property real lineWidth: 7
    // Degrees left open at the bottom of the ring.
    property real gapAngle: 70

    readonly property real centreX: width / 2
    readonly property real centreY: height / 2
    readonly property real radius: Math.min(width, height) / 2 - lineWidth / 2

    // 0 is east; the sweep grows clockwise. Starting at 90 + half the gap
    // leaves the opening centred at the bottom.
    readonly property real start: 90 + root.gapAngle / 2
    readonly property real sweep: 360 - root.gapAngle

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: root.trackColor
            strokeWidth: root.lineWidth
            capStyle: ShapePath.RoundCap
            fillColor: "transparent"

            PathAngleArc {
                centerX: root.centreX
                centerY: root.centreY
                radiusX: root.radius
                radiusY: root.radius
                startAngle: root.start
                sweepAngle: root.sweep
            }
        }

        ShapePath {
            strokeColor: root.fillColor
            strokeWidth: root.lineWidth
            capStyle: ShapePath.RoundCap
            fillColor: "transparent"

            PathAngleArc {
                centerX: root.centreX
                centerY: root.centreY
                radiusX: root.radius
                radiusY: root.radius
                startAngle: root.start
                sweepAngle: Math.max(0.01, root.sweep * Math.max(0, Math.min(1, root.value)))
            }
        }
    }
}
