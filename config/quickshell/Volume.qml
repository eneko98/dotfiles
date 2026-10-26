// The volume module: a speaker icon and the percentage of the default audio
// sink. Clicking it opens our own popup (VolumePopup.qml) with a slider and a
// mute toggle; the mixer is one click further, for per-application levels.
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

    // The bar routes this to the System panel; the module keeps its own
    // popup only for the control centre's hand-offs (both are retiring).
    signal activated()

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

    VolumePopup {
        id: popup
    }

    // TapHandler is a handler, not an Item, so it does not disturb the Row.
    // The popup hangs under the module: its right edge is the module's.
    // Also called by the control centre: the popup opens under the module no
    // matter where the request came from.
    function openPopup() {
        const p = root.mapToItem(null, 0, 0);
        popup.rightMargin = root.Window.width - (p.x + root.width);
        popup.visible = true;
    }

    TapHandler {
        onTapped: root.activated()
    }
}
