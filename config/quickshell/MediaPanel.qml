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
        visible: root.player !== null
        width: parent.width
        player: root.player
        onScreen: root.visible
    }

    // Nothing playing (a fresh boot): the last track, and a click that starts
    // Spotify again. The pill only opens this when there is something to show.
    Item {
        visible: root.player === null && Config.lastTitle !== ""
        width: parent.width
        implicitHeight: stale.implicitHeight

        Row {
            id: stale

            width: parent.width
            spacing: 12

            Vinyl {
                width: 96
                height: 96
                art: Config.lastArt
                playing: false
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 96 - 12
                spacing: 3

                Text {
                    width: parent.width
                    text: Config.lastTitle
                    color: Theme.fg1
                    font.family: "Adwaita Sans"
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: Config.lastArtist
                    color: Theme.fg2
                    font.family: "Adwaita Sans"
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: "Not playing — click to resume"
                    color: Theme.fg2
                    font.family: "Adwaita Sans"
                    font.pixelSize: 10
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                Quickshell.execDetached(["sh", "-c",
                    "$HOME/.config/hypr/scripts/spotify-toggle"]);
                root.close();
            }
        }
    }
}
