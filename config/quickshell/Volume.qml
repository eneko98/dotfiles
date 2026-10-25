// The volume module: a speaker icon and the percentage of the default audio
// sink. Clicking it opens pavucontrol, the mixer.
//
// Pipewire.defaultAudioSink is a live PwNode. Its audio.volume / audio.muted
// are only valid once the node is *bound*, which is what PwObjectTracker does;
// without it those properties read as invalid. The bindings below then update
// on their own when the volume changes, from this bar or from the keys.

import Quickshell
import Quickshell.Services.Pipewire
import QtQuick

Row {
    id: root

    spacing: 6

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var audio: sink ? sink.audio : null
    readonly property real volume: audio ? audio.volume : 0
    readonly property bool muted: audio ? audio.muted : false

    // Bind the default sink so its audio properties are usable.
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: root.muted ? "󰖁" : root.volume > 0.5 ? "󰕾" : root.volume > 0 ? "󰖀" : "󰕿"
        color: root.muted ? Theme.fg2 : Theme.fg1
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 14
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: Math.round(root.volume * 100) + "%"
        color: Theme.fg1
        font.family: "Adwaita Sans"
        font.pixelSize: 12
    }

    // TapHandler is a handler, not an Item, so it does not disturb the Row.
    TapHandler {
        onTapped: Quickshell.execDetached(["pavucontrol"])
    }
}
