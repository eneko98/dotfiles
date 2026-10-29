// A hand-drawn slider: 4 px track, accent fill, fg0 handle with a small
// shadow (18 px under the pointer). `value` is 0..1; dragging emits moved(),
// and the owner turns that into a volume or brightness change.
//
// Interaction: drag and click on the track; wheel is ±5 %; the arrow keys are
// ±5 % (±1 % with Shift). While dragging the value follows the finger with no
// animation -- an external change (media keys, another slider on the same
// node) animates over Motion.fast. The optional value label sits on the
// right, 12 px fg1, tabular so it does not breathe.
//
// QtQuick.Controls would bring its own look, so the few pixels are drawn here.
import QtQuick
import QtQuick.Effects

Item {
    id: root

    property real value: 0
    property color trackColor: Qt.rgba(Theme.fg0.r, Theme.fg0.g, Theme.fg0.b, 0.10)
    // When set, a tabular value label is drawn on the right.
    property string valueLabel: ""

    signal moved(real value)

    height: 18
    activeFocusOnTab: enabled

    // What is drawn: the live value while dragging (no animation), the bound
    // value otherwise (animated -- that is the "external change" path).
    property real _drag: 0
    property real shown: dragArea.dragging ? _drag : value

    Behavior on shown {
        enabled: !dragArea.dragging
        NumberAnimation {
            duration: Motion.fast
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.standard
        }
    }

    function _emit(x) {
        const v = Math.max(0, Math.min(1, x / track.width));
        root._drag = v;
        root.moved(v);
    }

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: root.width - (root.valueLabel !== "" ? label.width + 8 : 0)
        height: 4
        radius: 2
        color: root.trackColor

        Rectangle {
            width: parent.width * root.shown
            height: parent.height
            radius: 2
            color: root.enabled ? Theme.gold : Theme.fg2
        }
    }

    Text {
        id: label
        visible: root.valueLabel !== ""
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        text: root.valueLabel
        color: Theme.fg1
        font.family: "Adwaita Sans"
        font.pixelSize: 12
        font.features: ({ "tnum": 1 })
    }

    Rectangle {
        id: handle
        x: track.x + root.shown * (track.width - width)
        anchors.verticalCenter: parent.verticalCenter
        width: (dragArea.containsMouse || dragArea.dragging) && root.enabled ? 18 : 14
        height: width
        radius: width / 2
        color: root.enabled ? Theme.fg0 : Theme.fg2

        Behavior on width {
            NumberAnimation {
                duration: Motion.fast
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.standard
            }
        }

        RectangularShadow {
            anchors.fill: parent
            radius: parent.radius
            blur: 4
            offset.y: 1
            color: Qt.rgba(0, 0, 0, 0.30)
            cached: true
        }
    }

    // Drag. Note the handler form: arrow functions do not receive the event.
    MouseArea {
        id: dragArea
        property bool dragging: false
        anchors.fill: parent
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onPressed: function (mouse) {
            dragging = true;
            root._emit(mouse.x - track.x);
        }
        onPositionChanged: function (mouse) {
            if (dragging)
                root._emit(mouse.x - track.x);
        }
        onReleased: dragging = false
        onWheel: function (w) {
            const step = w.angleDelta.y > 0 ? 0.05 : -0.05;
            root.moved(Math.max(0, Math.min(1, root.value + step)));
        }
    }

    Keys.onPressed: function (event) {
        const fine = event.modifiers & Qt.ShiftModifier;
        const step = (fine ? 0.01 : 0.05);
        if (event.key === Qt.Key_Left || event.key === Qt.Key_Down) {
            root.moved(Math.max(0, root.value - step));
            event.accepted = true;
        } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Up) {
            root.moved(Math.min(1, root.value + step));
            event.accepted = true;
        }
    }
}
