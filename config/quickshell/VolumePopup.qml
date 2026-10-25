// The volume popup: the default sink's volume as a slider, a mute toggle and a
// way into pavucontrol for per-application levels.
//
// PwNodeAudio.volume and .muted are writable, and both are invalid unless the
// node is bound, which is what PwObjectTracker does (the Volume module does the
// same). Nothing here polls: the bar's percentage and the slider are bindings on
// the same node, so the keys, the popup and the mixer all stay in sync.

import Quickshell
import Quickshell.Services.Pipewire
import QtQuick

Popup {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var audio: sink ? sink.audio : null
    readonly property real volume: audio ? audio.volume : 0
    readonly property bool muted: audio ? audio.muted : false

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    Text {
        text: "Volume"
        color: Theme.fg1
        font.family: "Adwaita Sans"
        font.pixelSize: 11
    }

    Row {
        width: parent.width
        spacing: 8

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.muted ? "󰖁" : root.volume > 0.5 ? "󰕾" : root.volume > 0 ? "󰖀" : "󰕿"
            color: root.muted ? Theme.fg2 : Theme.fg0
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 18

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: if (root.audio)
                    root.audio.muted = !root.audio.muted
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Math.round(root.volume * 100) + "%"
            color: Theme.fg0
            font.family: "Adwaita Sans"
            font.pixelSize: 15
            font.bold: true
        }
    }

    // A slider is small enough to draw by hand: a track, a fill and a handle.
    Item {
        id: slider

        width: parent.width
        height: 18

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 4
            radius: 2
            color: Theme.bg2

            Rectangle {
                width: parent.width * root.volume
                height: parent.height
                radius: 2
                color: Theme.gold
            }
        }

        Rectangle {
            x: root.volume * (slider.width - width)
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
                if (root.audio)
                    root.audio.volume = Math.max(0, Math.min(1, x / width));
            }

            onPressed: function (mouse) { setFromX(mouse.x); }
            onPositionChanged: function (mouse) { if (pressed) setFromX(mouse.x); }
        }
    }

    // Per-application levels and devices still live in the mixer.
    Text {
        text: "Mixer"
        color: mixerHover.containsMouse ? Theme.gold : Theme.fg2
        font.family: "Adwaita Sans"
        font.pixelSize: 11

        MouseArea {
            id: mixerHover

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                root.visible = false;
                Quickshell.execDetached(["pavucontrol"]);
            }
        }
    }
}
