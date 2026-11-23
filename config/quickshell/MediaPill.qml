// The media pill. Two states:
//  - live: a player is playing (or paused with a title), shown as the reference
//    does -- a small round button with the play/pause glyph;
//  - stale: nothing is playing but the last track is remembered, shown as
//    "glyph + title — artist" so the bar is not empty at boot. Clicking it opens
//    the bubble, which offers to start Spotify again.
//
// The last track is persisted in Config, so it survives a reboot.
import Quickshell
import Quickshell.Services.Mpris
import QtQuick

Surface {
    id: root

    signal clicked()

    // The first player playing, else the first with a title (a paused track can
    // still be resumed). A title is required: playerctld registers itself as an
    // MPRIS player even with nothing behind it.
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

    readonly property bool live: player !== null && player.trackTitle !== ""
    readonly property bool stale: !root.live && Config.lastTitle !== ""

    readonly property string staleLabel: Config.lastArtist === ""
        ? Config.lastTitle : Config.lastTitle + " — " + Config.lastArtist

    level: 1
    lifted: hover.hovered
    width: root.live ? 38 : root.stale ? staleRow.implicitWidth + 24 : 0
    height: 30
    opacity: (root.live || root.stale) ? 1 : 0
    visible: root.live || root.stale

    Behavior on width {
        NumberAnimation {
            duration: Motion.medium
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.standard
        }
    }

    // Persist the live track whenever it changes, and once more shortly after
    // (metadata arrives after the player does).
    onLiveChanged: root.persist()
    onPlayerChanged: root.persist()

    function persist() {
        if (root.player !== null && root.player.trackTitle !== "")
            Config.saveLastTrack(root.player.trackTitle, root.player.trackArtist,
                                 root.player.trackArtUrl);
    }

    Timer {
        interval: 3000
        repeat: true
        running: root.player !== null
        onTriggered: root.persist()
    }

    HoverHandler { id: hover }

    MouseArea {
        anchors.fill: parent
        z: -1
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    Row {
        id: staleRow

        anchors.centerIn: parent
        spacing: 6

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.player && root.player.isPlaying ? "󰏤" : "󰐊"
            color: hover.hovered ? Theme.fg0 : Theme.fg1
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 15

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                enabled: root.live
                onClicked: if (root.player && root.player.canTogglePlaying)
                    root.player.togglePlaying()
            }
        }

        // Only the remembered track has a label; live, the pill stays the small
        // button of the reference and the title lives in the bubble.
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.stale
            width: Math.min(implicitWidth, 220)
            text: root.staleLabel
            elide: Text.ElideRight
            color: Theme.fg2
            font.family: "Adwaita Sans"
            font.pixelSize: 11
        }
    }
}
