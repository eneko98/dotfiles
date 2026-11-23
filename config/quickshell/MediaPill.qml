// The media pill. Two states:
//  - live: a player is playing (or paused with a title), shown as the reference
//    does -- a small round button with the play/pause glyph;
//  - stale: nothing is playing but the last track is remembered, shown as
//    "glyph + title — artist" for three seconds after the shell starts, then the
//    pill collapses: the bar must not carry a song that finished days ago. A
//    live player cancels that countdown.
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

    // The remembered track is a boot shortcut, not a label: three seconds and
    // it is gone. Coming back to live (or losing the remembered one) resets it.
    property bool staleExpired: false
    readonly property bool shown: root.live || (root.stale && !root.staleExpired)

    onStaleChanged: {
        root.staleExpired = false;
        if (root.stale)
            staleTimer.restart();
        else
            staleTimer.stop();
    }

    Timer {
        id: staleTimer
        interval: 3000
        onTriggered: root.staleExpired = true
    }

    readonly property string staleLabel: Config.lastArtist === ""
        ? Config.lastTitle : Config.lastTitle + " — " + Config.lastArtist

    level: 1
    lifted: hover.hovered
    width: root.live ? 38 : root.stale && !root.staleExpired
        ? staleRow.implicitWidth + 24 : 0
    height: 30
    opacity: root.shown ? 1 : 0
    visible: root.shown

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
