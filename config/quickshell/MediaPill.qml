// The media pill, as in the reference: a small round button with the play/pause
// glyph, nothing else. Clicking the glyph toggles playback; clicking the pill
// opens the media bubble. With no player it collapses to nothing, so the bar
// never shows an empty slot.
import Quickshell
import Quickshell.Services.Mpris
import QtQuick

Surface {
    id: root

    signal clicked()

    // The first player playing, else the first with a title (a paused track can
    // still be resumed from here). A title is required: playerctld registers
    // itself as an MPRIS player even with nothing behind it.
    readonly property var player: {
        const players = Mpris.players.values;
        let fallback = null;

        for (let i = 0; i < players.length; ++i) {
            if (players[i].isPlaying)
                return players[i];
            if (fallback === null && players[i].trackTitle !== "")
                fallback = players[i];
        }

        return fallback;
    }

    readonly property bool active: player !== null && player.trackTitle !== ""

    level: 1
    lifted: hover.hovered
    width: active ? 38 : 0
    height: 30
    opacity: active ? 1 : 0
    visible: active

    Behavior on width {
        NumberAnimation {
            duration: Motion.medium
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.standard
        }
    }

    HoverHandler { id: hover }

    MouseArea {
        anchors.fill: parent
        z: -1
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    Text {
        anchors.centerIn: parent
        text: root.player && root.player.isPlaying ? "󰏤" : "󰐊"
        color: hover.hovered ? Theme.fg0 : Theme.fg1
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 15

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: if (root.player && root.player.canTogglePlaying)
                root.player.togglePlaying()
        }
    }
}
