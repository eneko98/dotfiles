// The on-screen display: a small bubble at the bottom that appears when the
// volume or the brightness changes, then fades away on its own.
//
// It is a passive layer surface: no backdrop, no keyboard focus, ExclusionMode
// Ignore. It anchors to the bottom and is only mapped while it is needed, so it
// cannot swallow clicks the rest of the time.
//
// Volume arrives through Pipewire (the keys go through wpctl, which changes the
// same node the bar reads). Brightness has no signal: the backlight sysfs file
// is watched with FileView, which catches both the brightness keys and the
// control centre slider. `armed` waits a moment after startup so the first
// bindings do not flash an OSD nobody asked for.

import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: root

    anchors {
        bottom: true
        left: true
        right: true
    }

    implicitHeight: 64
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    visible: false

    property bool armed: false
    property real pillOpacity: 0
    property string glyph: ""
    property real value: 0
    property string text: ""
    property int lastBrightness: -1

    function flash(g, v, t) {
        root.glyph = g;
        root.value = Math.max(0, Math.min(1, v));
        root.text = t;
        root.visible = true;
        root.pillOpacity = 1;
        hideTimer.restart();
    }

    Timer {
        interval: 1200
        running: true
        onTriggered: root.armed = true
    }

    Timer {
        id: hideTimer
        interval: 1200
        onTriggered: {
            root.pillOpacity = 0;
            closeTimer.start();
        }
    }

    Timer {
        id: closeTimer
        interval: 160
        onTriggered: root.visible = false
    }

    // --- Volume -----------------------------------------------------------
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var audio: sink ? sink.audio : null
    readonly property real volume: audio ? audio.volume : 0
    readonly property bool muted: audio ? audio.muted : false

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    function volumeGlyph(value) {
        if (root.muted)
            return "󰖁";
        if (value > 0.5)
            return "󰕾";
        if (value > 0)
            return "󰖀";
        return "󰕿";
    }

    onVolumeChanged: {
        if (!root.armed)
            return;
        root.flash(root.volumeGlyph(root.volume), root.volume,
                   Math.round(root.volume * 100) + "%");
    }

    onMutedChanged: {
        if (!root.armed)
            return;
        root.flash(root.volumeGlyph(root.volume), root.volume,
                   root.muted ? "Muted" : Math.round(root.volume * 100) + "%");
    }

    // --- Brightness -------------------------------------------------------
    // The device node is the laptop's; if a second panel ever appears, this is
    // the line that needs a lookup instead of a literal.
    FileView {
        id: maxFile
        path: "/sys/class/backlight/amdgpu_bl1/max_brightness"
        blockLoading: true
    }

    readonly property int maxBrightness: parseInt(maxFile.text()) || 0

    FileView {
        id: brightnessFile
        path: "/sys/class/backlight/amdgpu_bl1/brightness"
        watchChanges: true

        onFileChanged: reload()

        onTextChanged: {
            if (!root.armed)
                return;

            const raw = parseInt(text());
            if (isNaN(raw) || root.maxBrightness <= 0)
                return;

            const pct = Math.round(raw / root.maxBrightness * 100);
            if (pct === root.lastBrightness)
                return;

            root.lastBrightness = pct;
            root.flash("󰃠", pct / 100, pct + "%");
        }
    }

    // --- The bubble -------------------------------------------------------
    Rectangle {
        anchors.centerIn: parent
        width: 300
        height: 40
        radius: 10
        color: Qt.rgba(Theme.bg1.r, Theme.bg1.g, Theme.bg1.b, 0.95)
        border.width: 1
        border.color: Theme.bg2

        opacity: root.pillOpacity

        Behavior on opacity {
            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
        }

        Text {
            id: glyphText

            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter

            text: root.glyph
            color: Theme.fg1
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 16
        }

        Text {
            id: valueText

            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter

            width: 40
            horizontalAlignment: Text.AlignRight
            text: root.text
            color: Theme.fg1
            font.family: "Adwaita Sans"
            font.pixelSize: 11
        }

        Item {
            anchors.left: glyphText.right
            anchors.leftMargin: 12
            anchors.right: valueText.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            height: 6

            Rectangle {
                anchors.fill: parent
                radius: 3
                color: Theme.bg2
            }

            Rectangle {
                width: parent.width * root.value
                height: parent.height
                radius: 3
                color: Theme.gold
            }
        }
    }
}
