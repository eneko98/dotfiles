// A thin bar, shared by the fetch rows and the vinyl progress so both cards
// speak the same language. NaN draws the bare track (no data yet).
//
// `animated` (not `smooth`, which Item already has) turns the width Behavior
// off: a seek or a jump back to the desktop is not a glide, it should snap.
// `linear` + `glide: pollMs` is how the vinyl progress advances continuously
// from one reading per second, without any JS per frame.
import QtQuick

Item {
    id: root

    property real value: 0
    property color fill: Theme.fg1
    property bool animated: true
    property int glide: Motion.base
    property bool linear: false

    implicitHeight: 3

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Qt.rgba(Theme.fg0.r, Theme.fg0.g, Theme.fg0.b, 0.10)
    }

    Rectangle {
        height: parent.height
        radius: height / 2
        color: root.fill
        width: parent.width * (isNaN(root.value) ? 0
            : Math.max(0, Math.min(1, root.value)))

        Behavior on width {
            enabled: root.animated
            NumberAnimation {
                duration: root.glide
                easing.type: root.linear ? Easing.Linear
                    : Easing.BezierSpline
                easing.bezierCurve: Motion.standard
            }
        }
    }
}
