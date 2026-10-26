// A small analog clock: a quiet face (bg2 60%), twelve ticks with the
// quarters slightly heavier, hour and minute hands in fg0, and a second
// hand in the neon. The second hand ticks once a second while `running` --
// the host binds that to being on screen, so no panel, no timer.
import QtQuick

Item {
    id: root

    property real size: 44
    property date now: new Date()
    property bool running: false

    width: size
    height: size

    onRunningChanged: if (running) tick.restart()
    onVisibleChanged: if (visible) root.now = new Date()

    Timer {
        id: tick
        interval: 1000
        running: root.running && root.visible
        repeat: true
        onTriggered: root.now = new Date()
    }

    // The hands' angles: 30 deg an hour (+ a nudge per minute), 6 deg a
    // minute (+ a nudge per second), 6 deg a second.
    readonly property real hourAngle: (now.getHours() % 12) * 30 + now.getMinutes() * 0.5
    readonly property real minuteAngle: now.getMinutes() * 6 + now.getSeconds() * 0.1
    readonly property real secondAngle: now.getSeconds() * 6

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: Qt.rgba(Theme.bg2.r, Theme.bg2.g, Theme.bg2.b, 0.60)
        border.width: 1
        border.color: Qt.rgba(Theme.fg0.r, Theme.fg0.g, Theme.fg0.b, 0.08)
    }

    Repeater {
        model: 12

        delegate: Rectangle {
            required property int index

            width: 2
            height: index % 3 === 0 ? 5 : 3
            radius: 1
            color: index % 3 === 0 ? Theme.fg1 : Theme.fg2
            x: root.width / 2 - 1
            y: 3
            transform: Rotation {
                origin.x: 1
                origin.y: root.width / 2 - 3
                angle: index * 30
            }
        }
    }

    component Hand: Rectangle {
        id: hand

        property real angle: 0
        property real handLength: 10
        property real handWidth: 2.5

        width: handWidth
        height: handLength
        radius: handWidth / 2
        x: root.width / 2 - handWidth / 2
        y: root.height / 2 - handLength
        transform: Rotation {
            origin.x: hand.handWidth / 2
            origin.y: hand.handLength
            angle: hand.angle
        }
    }

    Hand {
        angle: root.hourAngle
        handLength: root.size * 0.24
        handWidth: 3
        color: Theme.fg0
    }

    Hand {
        angle: root.minuteAngle
        handLength: root.size * 0.34
        handWidth: 2.5
        color: Theme.fg0
    }

    Hand {
        angle: root.secondAngle
        handLength: root.size * 0.38
        handWidth: 1.5
        color: Theme.teal
    }

    Rectangle {
        anchors.centerIn: parent
        width: 4
        height: 4
        radius: 2
        color: Theme.fg0
    }
}
