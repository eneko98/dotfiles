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

    Slider {
        width: parent.width
        value: root.volume

        onMoved: function (value) {
            if (root.audio)
                root.audio.volume = value;
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
