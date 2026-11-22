// The media bubble: what the media pill opens. The card itself is MediaCard,
// the same one Today shows, so the vinyl, the seek bar and the controls are not
// duplicated -- only the surface around it is new.
import Quickshell
import Quickshell.Services.Mpris
import QtQuick

Popup {
    id: root

    panelWidth: 380

    // Same pick as the pill: the first playing, else the first with a title.
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

    MediaCard {
        width: parent.width
        player: root.player
        onScreen: root.visible
    }
}
