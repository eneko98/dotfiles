// An elevated surface: the shared chrome for pills, cards and panels. It is a
// rounded rect with a hairline edge, a top highlight and a real drop shadow
// (RectangularShadow, Qt 6.9+; this system runs 6.12).
//
// `level` picks the elevation bag from Tokens (1 pill, 2 island/card, 3
// panel); `lifted` is the hover state, which raises the surface one level
// instead of swapping a colour -- that is what makes the chrome read as
// physical. The shadow sits at z: -1 so it renders under the fill but still
// inside the window; `extra` adds fill alpha (the expanded island uses it).
//
// Colours come from Theme.qml; the numbers come from Tokens.qml. No hex here.
import QtQuick
import QtQuick.Effects
import Quickshell

Rectangle {
    id: root

    property int level: 1
    property bool lifted: false
    property real extra: 0.0

    readonly property var t: Tokens.level(level, lifted)

    // A pill by default (half-height); panels override with Tokens.radius.panel.
    radius: height / 2

    color: {
        const a = Tokens.blur ? t.fill : t.fillSolid;
        return Qt.rgba(Theme.bg1.r, Theme.bg1.g, Theme.bg1.b,
                       Math.min(1, a + root.extra));
    }
    border.width: 1
    border.color: Qt.rgba(Theme.fg0.r, Theme.fg0.g, Theme.fg0.b, t.stroke)

    RectangularShadow {
        z: -1
        anchors.fill: parent
        radius: root.radius
        blur: root.t.shadowBlur
        offset.y: root.t.shadowY
        color: Qt.rgba(0, 0, 0, root.t.shadowAlpha)
        cached: true
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

    Behavior on color {
        ColorAnimation { duration: Motion.fast }
    }
}
