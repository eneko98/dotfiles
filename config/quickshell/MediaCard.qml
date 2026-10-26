// The media card: art (or a note glyph), title, artist, the three transport
// controls and a 3px progress bar with times. Seekable only when the player
// says canSeek. Position is polled once a second WHILE THE CARD IS VISIBLE
// -- MPRIS position is a DBus read, so the poll lives with the card, not
// with the session. Multiple players: chips above (the host picks; the card
// renders one player).
import Quickshell.Services.Mpris
import QtQuick

Column {
    id: root

    property var player: null
    // The host binds this to the card's actual on-screen state: the poll
    // (and only the poll) depends on it. Named onScreen: shadowing Item's
    // visible would break the layout's include/exclude semantics.
    property bool onScreen: false

    // Polled position: `player.position` is a live property but MPRIS does
    // not push ticks; a second-cadence read while visible is the deal.
    property real pos: player ? player.position : 0

    onPlayerChanged: root.pos = player ? player.position : 0

    Timer {
        interval: 1000
        running: root.onScreen && root.player !== null
        repeat: true
        onTriggered: root.pos = root.player.position
    }

    width: parent.width
    spacing: Tokens.space.s

    readonly property real length: player ? player.length : 0

    function fmt(us) {
        if (!us || us <= 0)
            return "0:00";
        const total = Math.floor(us / 1000000);
        return Math.floor(total / 60) + ":" + ("0" + total % 60).slice(-2);
    }

    // --- Art + track ------------------------------------------------------
    Row {
        width: parent.width
        spacing: Tokens.space.m

        Rectangle {
            width: 56
            height: 56
            radius: Tokens.radius.control
            color: Theme.bg2
            clip: true

            Image {
                anchors.fill: parent
                visible: root.player && root.player.trackArtUrl !== ""
                source: root.player ? root.player.trackArtUrl : ""
                fillMode: Image.PreserveAspectCrop
            }

            Glyph {
                visible: !root.player || root.player.trackArtUrl === ""
                anchors.centerIn: parent
                glyph: "󰎈"
                size: 22
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 56 - Tokens.space.m
            spacing: 2

            Text {
                width: parent.width
                text: root.player ? root.player.trackTitle : ""
                color: Theme.fg0
                font.family: "Adwaita Sans"
                font.pixelSize: 13
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: root.player ? (root.player.trackArtist || root.player.trackAlbum) : ""
                color: Theme.fg1
                font.family: "Adwaita Sans"
                font.pixelSize: 12
                elide: Text.ElideRight
            }
        }
    }

    // --- Controls + progress ---------------------------------------------
    Row {
        spacing: Tokens.space.s

        Pressable {
            width: 32
            height: 32

            onClicked: if (root.player && root.player.canGoPrevious) root.player.previous()

            Glyph {
                anchors.centerIn: parent
                glyph: "󰙢"
                size: 15
            }
        }

        Pressable {
            width: 32
            height: 32

            onClicked: if (root.player && root.player.canTogglePlaying) root.player.togglePlaying()

            Glyph {
                anchors.centerIn: parent
                glyph: root.player && root.player.isPlaying ? "󰏤" : "󰐊"
                tone: "attention"
                size: 15
            }
        }

        Pressable {
            width: 32
            height: 32

            onClicked: if (root.player && root.player.canGoNext) root.player.next()

            Glyph {
                anchors.centerIn: parent
                glyph: "󰒭"
                size: 15
            }
        }
    }

    Item {
        width: parent.width
        height: 16

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: root.fmt(root.pos)
            color: Theme.fg1
            font.family: "Adwaita Sans"
            font.pixelSize: 11
            font.features: ({ "tnum": 1 })
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.fmt(root.length)
            color: Theme.fg1
            font.family: "Adwaita Sans"
            font.pixelSize: 11
            font.features: ({ "tnum": 1 })
        }

        // The 3px bar; draggable when the player seeks.
        Rectangle {
            anchors.left: parent.left
            anchors.leftMargin: 44
            anchors.right: parent.right
            anchors.rightMargin: 44
            anchors.verticalCenter: parent.verticalCenter
            height: 3
            radius: 1.5
            color: Qt.rgba(Theme.fg0.r, Theme.fg0.g, Theme.fg0.b, 0.10)

            Rectangle {
                width: parent.width
                    * (root.length > 0 ? Math.min(1, root.pos / root.length) : 0)
                height: parent.height
                radius: 1.5
                color: Theme.fg1
            }

            MouseArea {
                enabled: root.player ? root.player.canSeek : false
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor

                onPressed: function (mouse) {
                    if (root.player && root.length > 0)
                        root.player.setPosition(
                            Math.max(0, Math.min(1, mouse.x / width)) * root.length);
                }
            }
        }
    }
}
