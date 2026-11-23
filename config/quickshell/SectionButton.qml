// One icon of the bar's section row: a 22 px round hover background and the
// glyph. `current` dims it to 35 % (the reference's "not active" look) when the
// feature behind it is off.
import QtQuick

Item {
    id: root

    property string glyph: ""
    property bool current: true

    signal clicked()

    width: 26
    height: 30

    HoverHandler { id: hover }

    Rectangle {
        anchors.centerIn: parent
        width: 22
        height: 22
        radius: 11
        color: hover.hovered
            ? Qt.rgba(Theme.bg2.r, Theme.bg2.g, Theme.bg2.b, 0.85)
            : "transparent"
    }

    Text {
        anchors.centerIn: parent
        text: root.glyph
        color: root.current ? Theme.fg1 : Theme.fg2
        opacity: root.current ? 1 : 0.55
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 14

        Behavior on opacity {
            NumberAnimation {
                duration: Motion.fast
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.standard
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
