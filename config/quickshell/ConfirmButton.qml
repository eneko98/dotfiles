// A two-step destructive button: Reboot, Power Off, Log out, kill a process.
//
// 1. First click: the button fills red, text/glyph go bg0, a tooltip says
//    "Click again to <action>", and a 2 px line along the base drains for
//    3 s.
// 2. Second click within 3 s: `confirmed()` fires.
// 3. After 3 s, Escape or focus loss: back to the ghost state (Motion.fast).
//
// Red is exclusively the alarm colour, and a destructive confirmation is an
// alarm: the rest state is a ghost pill in the accent family (the same shape
// the greeter's power pills use), so red appears only when the action is
// actually about to happen.
import QtQuick

Pressable {
    id: root

    property string label: ""
    property string glyph: ""
    property string confirmText: ""
    property int armedMs: 3000
    // 40px icon buttons show only the glyph; the tooltip carries the label.
    property bool showLabel: true

    signal confirmed()

    readonly property bool armed: armTimer.running

    onClicked: {
        if (root.armed) {
            root.disarm();
            root.confirmed();
        } else {
            armTimer.restart();
            drain.restart();
        }
    }
    Keys.onEscapePressed: root.disarm()
    onActiveFocusChanged: if (!activeFocus) root.disarm()

    function disarm() {
        armTimer.stop();
        drain.stop();
    }

    Timer {
        id: armTimer
        interval: root.armedMs
        onTriggered: root.disarm()
    }

    Rectangle {
        id: body
        anchors.fill: parent
        radius: height / 2
        color: root.armed
            ? Theme.red
            : Qt.rgba(Theme.bg1.r, Theme.bg1.g, Theme.bg1.b, 0.70)
        border.width: 1
        border.color: root.armed
            ? "transparent"
            : Qt.rgba(Theme.gold.r, Theme.gold.g, Theme.gold.b, 0.30)

        Behavior on color {
            ColorAnimation { duration: Motion.fast }
        }

        Row {
            anchors.centerIn: parent
            spacing: Tokens.space.xs

            Glyph {
                visible: root.glyph !== ""
                anchors.verticalCenter: parent.verticalCenter
                glyph: root.glyph
                // bg0 text on the red fill: `disabled` is the slot that
                // carries bg0 in the glyph tones.
                tone: root.armed ? "disabled" : "normal"
                size: 13
            }

            Text {
                visible: root.showLabel
                anchors.verticalCenter: parent.verticalCenter
                text: root.label
                color: root.armed ? Theme.bg0 : Theme.fg1
                font.family: "Adwaita Sans"
                font.pixelSize: 12

                Behavior on color {
                    ColorAnimation { duration: Motion.fast }
                }
            }
        }

        // The countdown: 2 px line along the base, full width to zero,
        // linear over armedMs. `progress` is animated by the drain run.
        Rectangle {
            id: drainLine
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            height: 2
            radius: 1
            width: parent.width * progress
            visible: root.armed
            color: Theme.bg0

            property real progress: 1
        }
    }

    NumberAnimation {
        id: drain
        target: drainLine
        property: "progress"
        from: 1
        to: 0
        duration: root.armedMs
        easing.type: Easing.Linear
    }

    Tooltip {
        hovered: root.armed || root.hovered
        delay: root.armed ? 0 : 500
        label: root.armed && root.confirmText !== "" ? root.confirmText : root.label
        below: false
        anchors.bottom: parent.top
        anchors.bottomMargin: Tokens.space.xs
        anchors.horizontalCenter: parent.horizontalCenter
    }
}
