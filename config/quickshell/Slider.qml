// A hand-drawn slider: track, gold fill and handle. `value` is 0..1; dragging
// emits moved(), and the owner turns that into a volume or brightness change.
// QtQuick.Controls would bring its own look, so the few pixels are drawn here.

import QtQuick

Item {
    id: root

    property real value: 0
    property color trackColor: Theme.bg2

    signal moved(real value)

    height: 18

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 4
        radius: 2
        color: root.trackColor

        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, root.value))
            height: parent.height
            radius: 2
            color: Theme.gold
        }
    }

    Rectangle {
        x: Math.max(0, Math.min(1, root.value)) * (root.width - width)
        anchors.verticalCenter: parent.verticalCenter
        width: 8
        height: 16
        radius: 4
        color: Theme.fg0
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor

        function setFromX(x) {
            root.moved(Math.max(0, Math.min(1, x / width)));
        }

        onPressed: function (mouse) { setFromX(mouse.x); }
        onPositionChanged: function (mouse) { if (pressed) setFromX(mouse.x); }
    }
}
