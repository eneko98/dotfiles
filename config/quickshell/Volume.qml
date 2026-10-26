// The volume glyph in the status pill: display and interactions only -- the
// System panel owns the controls. Click opens System's sound section;
// right-click mutes; the wheel steps +-5% (the island surfaces the change);
// the hover tooltip carries the number the bar no longer shows.
import Quickshell
import Quickshell.Services.Pipewire
import QtQuick

Item {
    id: root

    signal activated(string section)

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var audio: sink ? sink.audio : null
    readonly property real volume: audio ? audio.volume : 0
    readonly property bool muted: audio ? audio.muted : false

    width: 20
    height: 30

    Pressable {
        id: press

        anchors.fill: parent

        onClicked: root.activated("sound")
        onSecondaryClicked: {
            if (root.audio)
                root.audio.muted = !root.audio.muted;
        }
        // Pressable exposes the wheel as scrolled(dy) (dy = angleDelta.y):
        // the touchpad populates it too, so this covers both.
        onScrolled: function (dy) {
            const step = dy > 0 ? 0.05 : -0.05;
            if (root.audio)
                root.audio.volume = Math.max(0, Math.min(1, root.audio.volume + step));
        }

        Glyph {
            anchors.centerIn: parent
            glyph: root.muted ? "󰖁"
                : root.volume > 0.5 ? "󰕾"
                : root.volume > 0 ? "󰖀" : "󰕿"
            tone: "normal"
            // The speaker glyph's ink is small for its box; 18 brings its
            // visual height level with the wifi/bluetooth glyphs at 15.
            size: 18
        }
    }

    Tooltip {
        hovered: press.hovered
        label: root.muted ? "Muted" : "Volume " + Math.round(root.volume * 100) + "%"
        below: false
        anchors.bottom: parent.top
        anchors.bottomMargin: Tokens.space.xs
        anchors.horizontalCenter: parent.horizontalCenter
    }
}
