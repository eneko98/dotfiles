// The media pill: the play/pause glyph of whatever is playing, and a click that
// opens the media bubble. It is the piece that used to live inside the island,
// moved out so the island is only the clock (and the notification surface).
//
// The glyph toggles playback; the rest of the pill opens the panel. Same
// arrangement as the reference bar: a small pause button next to the clock.
import Quickshell
import Quickshell.Services.Mpris
import QtQuick

Surface {
    id: root

    signal clicked()

    // Same player the island used: the first one playing, else the first with a
    // title, so a paused track can be resumed from here.
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

    // A player with no track is not media: playerctld registers itself as an
    // MPRIS player even with nothing behind it, which painted an empty pill.
    readonly property bool active: player !== null && player.trackTitle !== ""

    level: 1
    lifted: hover.hovered
    // Collapses to nothing with no player, so the bar does not show an empty
    // pill: `visible` on the pill keeps its slot out of the row.
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
        // The MDI box sits ~1 px high at this size; same nudge as the island.
        anchors.verticalCenterOffset: 0
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
