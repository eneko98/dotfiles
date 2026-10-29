// An elevated surface: the shared chrome for pills, cards and panels. It is a
// rounded rect with a hairline edge, a top highlight and a real drop shadow
// (RectangularShadow, Qt 6.9+; this system runs 6.12).
//
// `level` picks the elevation bag from Tokens (1 pill, 2 island/card, 3
// panel); `lifted` is the hover state. The shadow stays at the base level:
// changing the blur radius on hover looks like a flicker, so the hover is read
// through colour, border and a 1 px lift of the fill layer only.
//
// Colours come from Theme.qml; the numbers come from Tokens.qml. No hex here.
import QtQuick
import QtQuick.Effects
import Quickshell

Item {
    id: root

    property int level: 1
    property bool lifted: false
    property real extra: 0.0

    // Appearance: lifted raises colour/border one level.
    readonly property var t: Tokens.level(level, lifted)
    // Shadow: stays at the base level so its blur never snaps.
    readonly property var shadowT: Tokens.level(level, false)

    // Exposed so callers (MorphPanel) can override the corner radius.
    property real radius: height / 2
    // Exposed so callers (Overview cards) can override the border colour.
    property color borderColor: Qt.rgba(Theme.fg0.r, Theme.fg0.g, Theme.fg0.b, root.t.stroke)

    // The visible surface: lifted 1 px on hover, shadow stays put.
    Rectangle {
        id: fill
        anchors.fill: parent
        radius: root.radius

        property real liftY: root.lifted ? -1 : 0

        color: {
            const a = Tokens.blur ? root.t.fill : root.t.fillSolid;
            return Qt.rgba(Theme.bg1.r, Theme.bg1.g, Theme.bg1.b,
                           Math.min(1, a + root.extra));
        }
        border.width: 1
        border.color: root.borderColor

        transform: Translate { y: fill.liftY }

        Behavior on color {
            ColorAnimation {
                duration: Motion.fast
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.standard
            }
        }
        Behavior on liftY {
            NumberAnimation {
                duration: Motion.fast
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.standard
            }
        }

        // The lit-from-above line: inset by a third of the corner radius so it
        // spans the flat part of the top edge.
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: parent.radius / 3
            anchors.leftMargin: parent.radius / 3
            anchors.rightMargin: parent.radius / 3
            height: 1
            color: Qt.rgba(Theme.fg0.r, Theme.fg0.g, Theme.fg0.b, root.t.highlight)
        }
    }

    RectangularShadow {
        z: -1
        anchors.fill: parent
        radius: root.radius
        blur: root.shadowT.shadowBlur
        offset.y: root.shadowT.shadowY
        color: Qt.rgba(0, 0, 0, root.shadowT.shadowAlpha)
        cached: true
    }
}
