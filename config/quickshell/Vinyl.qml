// A record. Black disc with grooves, the album art as the centre label and the
// spindle hole, turning while the track plays and holding its angle when it is
// paused (a paused record does not rewind).
//
// The label is an Avatar -- a Canvas -- because QML's `clip` ignores radius:
// a Rectangle with `radius` and `clip: true` still clips to its bounding box.
import QtQuick

Item {
    id: root

    property string art: ""
    property bool playing: false
    property real size: 120

    // Six seconds per turn: 33 rpm is ~1.8 s, which on a 120 px disc reads as a
    // blur rather than a record.
    property int turnDuration: 6000

    width: size
    height: size

    Item {
        id: disc

        anchors.fill: parent

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: Theme.bg0
            border.width: 1
            border.color: Qt.rgba(Theme.fg0.r, Theme.fg0.g, Theme.fg0.b, 0.12)
        }

        // The grooves are what makes a turning circle read as a record.
        Repeater {
            model: 5

            Rectangle {
                anchors.centerIn: parent
                width: disc.width * (0.93 - index * 0.07)
                height: width
                radius: width / 2
                color: "transparent"
                border.width: 1
                border.color: Qt.rgba(Theme.fg0.r, Theme.fg0.g, Theme.fg0.b, 0.07)
            }
        }

        Avatar {
            anchors.centerIn: parent
            size: disc.width * 0.52
            source: root.art
        }

        Rectangle {
            anchors.centerIn: parent
            width: Math.max(4, disc.width * 0.05)
            height: width
            radius: width / 2
            color: Theme.bg1
            border.width: 1
            border.color: Qt.rgba(Theme.fg0.r, Theme.fg0.g, Theme.fg0.b, 0.25)
        }
    }

    // Light on the vinyl stays put while the disc turns, like a real one.
    Rectangle {
        anchors.fill: parent
        radius: width / 2
        border.width: 0

        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.07) }
            GradientStop { position: 0.45; color: "transparent" }
            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.22) }
        }
    }

    NumberAnimation {
        id: spin

        target: disc
        property: "rotation"
        duration: root.turnDuration
        loops: Animation.Infinite
    }

    // NumberAnimation with loops leaves the property where it stopped, so a
    // pause freezes the angle. Restarting from that angle (instead of 0) is what
    // keeps a resumed track from snapping the label round.
    function updateSpin() {
        spin.stop();
        if (!root.playing)
            return;

        spin.from = disc.rotation;
        spin.to = disc.rotation + 360;
        spin.start();
    }

    onPlayingChanged: root.updateSpin()
    Component.onCompleted: root.updateSpin()
}
