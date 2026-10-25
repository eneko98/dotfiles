// What the island shows when something is playing: a play/pause glyph and the
// track, elided to a fixed width so a long title cannot take over the bar.
//
// The player is picked from Mpris.players: the first one actually playing, or
// failing that the first with a title (a paused player should still be
// resumable from the bar). The date next to the clock steps aside while this is
// visible, see shell.qml.
//
// Accessing player properties inside the binding is what makes it reactive:
// QML records each read, so isPlaying and the track metadata updates re-run it.

import Quickshell
import Quickshell.Services.Mpris
import QtQuick

Row {
    id: root

    spacing: 6

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

    readonly property bool active: player !== null

    readonly property string label: {
        if (root.player === null)
            return "";

        const title = root.player.trackTitle || "Unknown title";
        const artist = root.player.trackArtist;

        return artist === "" ? title : title + " — " + artist;
    }

    visible: root.active

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: root.player && root.player.isPlaying ? "󰏤" : "󰐊"
        color: Theme.fg1
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 14

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: if (root.player && root.player.canTogglePlaying)
                root.player.togglePlaying()
        }
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(implicitWidth, 200)
        text: root.label
        color: Theme.fg1
        font.family: "Source Han Serif CN"
        font.pixelSize: 11
        elide: Text.ElideRight
    }
}
