// A tooltip: e3, radius 8, padding 8x10, 12 px fg0 with an optional second
// line in fg1. It appears 500 ms into a hover with a fast fade and a 4 px
// rise, and vanishes without delay when the hover ends. It draws wherever its
// owner puts it (in the bar window it needs no input, so it stays outside the
// mask) and it never covers the expanded island -- anchoring is the owner's
// business. The 4 px entrance shift moves the content, never the tooltip
// itself, so the owner's anchors stay untouched.
//
// `hovered` is bound by the owner (usually a Pressable's `hovered`).
import QtQuick

Surface {
    id: root

    property bool hovered: false
    property string label: ""
    property string sub: ""
    // True when the tooltip sits below its anchor: the content rises up into
    // place instead of dropping down.
    property bool below: true

    level: 3
    radius: Tokens.radius.control

    width: Math.max(labelText.implicitWidth, subText.implicitWidth) + 20
    height: sub !== "" ? 48 : 30
    readonly property bool shown: hoverTimerPassed

    // The hover delay before showing (ms). The ConfirmButton's armed tooltip
    // sets it to 0: the countdown is short.
    property int delay: 500
    property bool hoverTimerPassed: false

    onHoveredChanged: {
        if (hovered) {
            hoverTimerPassed = false;
            showTimer.restart();
        } else {
            // Leaving: no delay on the way out.
            showTimer.stop();
            hoverTimerPassed = false;
        }
    }

    Timer {
        id: showTimer
        interval: root.delay
        onTriggered: root.hoverTimerPassed = true
    }

    Behavior on opacity {
        NumberAnimation {
            duration: Motion.fade
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.decel
        }
    }

    opacity: shown ? 1 : 0

    Item {
        anchors.fill: parent
        // The entrance shift: 4 px towards the anchor, sliding into place.
        y: root.shown ? 0 : (root.below ? 4 : -4)

        Behavior on y {
            NumberAnimation {
                duration: Motion.fast
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.decel
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: 2

            Text {
                id: labelText
                text: root.label
                color: Theme.fg0
                font.family: "Adwaita Sans"
                font.pixelSize: 12
            }

            Text {
                id: subText
                visible: root.sub !== ""
                text: root.sub
                color: Theme.fg1
                font.family: "Adwaita Sans"
                font.pixelSize: 10
            }
        }
    }
}
