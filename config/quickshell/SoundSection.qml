// Sound: the mute button (glyph by level), the volume slider and the
// percentage in one row; the chevron opens the detail -- output and input
// radios (click sets the default through wpctl; Quickshell's
// defaultAudioSink is read-only) and the pavucontrol link for the mixer.
//
// The node bindings are invalid unless tracked, so the PwObjectTracker sits
// here; the media keys, this slider and the bar all read the same node.
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick

Column {
    id: root

    property bool expanded: false

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var audio: sink ? sink.audio : null
    readonly property real volume: audio ? audio.volume : 0
    readonly property bool muted: audio ? audio.muted : false

    readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink)
    readonly property var sources: Pipewire.nodes.values.filter(n => n.isSource && !n.isSink)

    width: parent.width
    spacing: Tokens.space.s

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    // --- The row ----------------------------------------------------------
    Item {
        width: parent.width
        height: 32

        Pressable {
            id: muteButton
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 28
            height: 28

            onClicked: {
                if (root.audio)
                    root.audio.muted = !root.audio.muted;
            }

            Glyph {
                anchors.centerIn: parent
                glyph: root.muted ? "󰖁"
                    : root.volume > 0.5 ? "󰕾"
                    : root.volume > 0 ? "󰖀" : "󰕿"
                tone: root.muted ? "disabled" : "normal"
                size: 15
            }
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 34
            horizontalAlignment: Text.AlignRight
            text: Math.round(root.volume * 100) + "%"
            color: Theme.fg1
            font.family: "Adwaita Sans"
            font.pixelSize: 11
            font.features: ({ "tnum": 1 })
        }

        Pressable {
            id: expand
            anchors.right: parent.right
            anchors.rightMargin: 38
            anchors.verticalCenter: parent.verticalCenter
            width: 24
            height: 24

            onClicked: root.expanded = !root.expanded

            Text {
                anchors.centerIn: parent
                text: "󰅂"
                color: Theme.fg1
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                rotation: root.expanded ? 90 : 0

                Behavior on rotation {
                    NumberAnimation {
                        duration: Motion.fast
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Motion.standard
                    }
                }
            }
        }

        Slider {
            anchors.left: muteButton.right
            anchors.leftMargin: Tokens.space.s
            anchors.right: parent.right
            anchors.rightMargin: 70
            anchors.verticalCenter: parent.verticalCenter
            value: root.volume

            onMoved: function (value) {
                if (root.audio)
                    root.audio.volume = value;
            }
        }
    }

    // --- The detail -------------------------------------------------------
    Item {
        width: parent.width
        height: root.expanded ? detailCol.implicitHeight : 0
        clip: true

        Behavior on height {
            NumberAnimation {
                duration: Motion.medium
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.standard
            }
        }

        Column {
            id: detailCol
            width: parent.width
            spacing: Tokens.space.xs

            Text {
                text: "Output"
                color: Theme.fg2
                font.family: "Adwaita Sans"
                font.pixelSize: 10
            }

            Repeater {
                model: root.sinks

                delegate: DeviceRadio {
                    device: modelData
                    isDefault: Pipewire.defaultAudioSink
                               && modelData.id === Pipewire.defaultAudioSink.id
                }
            }

            Text {
                text: "Input"
                color: Theme.fg2
                font.family: "Adwaita Sans"
                font.pixelSize: 10
            }

            Repeater {
                model: root.sources

                delegate: DeviceRadio {
                    device: modelData
                    isDefault: Pipewire.defaultAudioSource
                               && modelData.id === Pipewire.defaultAudioSource.id
                }
            }

            Pressable {
                width: soundSettingsText.implicitWidth + Tokens.space.s * 2
                height: 24

                onClicked: Quickshell.execDetached(["pavucontrol"])

                Text {
                    id: soundSettingsText
                    anchors.centerIn: parent
                    text: "Sound settings"
                    color: parent.hovered ? Theme.gold : Theme.fg1
                    font.family: "Adwaita Sans"
                    font.pixelSize: 11
                }
            }
        }
    }

    // One device row: the radio dot and the device description.
    component DeviceRadio: Pressable {
        id: deviceRow

        property var device: null
        property bool isDefault: false

        width: parent.width
        height: 28

        onClicked: {
            if (deviceRow.device)
                Quickshell.execDetached(["wpctl", "set-default", deviceRow.device.id]);
        }

        Rectangle {
            anchors.left: parent.left
            anchors.leftMargin: Tokens.space.s
            anchors.verticalCenter: parent.verticalCenter
            width: 10
            height: 10
            radius: 5
            color: deviceRow.isDefault ? Theme.gold : "transparent"
            border.width: 1
            border.color: deviceRow.isDefault ? Theme.gold : Theme.fg2

            Behavior on color {
                ColorAnimation { duration: Motion.fast }
            }
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: Tokens.space.l
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: deviceRow.device ? deviceRow.device.description : ""
            color: deviceRow.isDefault ? Theme.fg0 : Theme.fg1
            font.family: "Adwaita Sans"
            font.pixelSize: 12
            elide: Text.ElideRight
        }
    }
}
