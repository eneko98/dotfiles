// The media card in Today: large art, title/artist/album, a seekable progress
// bar and the transport controls (previous, play/pause, next) plus shuffle
// and loop when the player supports them.
//
// Position is polled once a second WHILE THE CARD IS ON SCREEN -- MPRIS
// position is a DBus read and MPRIS does not push ticks. `player` is chosen by
// the host (one player per card).
import Quickshell.Services.Mpris
import QtQuick

Column {
    id: root

    property var player: null
    // The host binds this to the card's actual on-screen state: the poll (and
    // only the poll) depends on it. Named onScreen: shadowing Item's visible
    // would break the layout's include/exclude semantics.
    property bool onScreen: false

    property real pos: player ? player.position : 0
    onPlayerChanged: root.pos = player ? player.position : 0

    Timer {
        interval: 1000
        running: root.onScreen && root.player !== null
        repeat: true
        onTriggered: root.pos = root.player.position
    }

    width: parent.width
    spacing: Tokens.space.m

    readonly property real length: player ? player.length : 0

    function fmt(s) {
        if (!s || s <= 0)
            return "0:00";
        const total = Math.floor(s);
        return Math.floor(total / 60) + ":" + ("0" + total % 60).slice(-2);
    }

    // None -> Playlist -> Track -> None: the order Spotify uses.
    function cycleLoop() {
        if (!root.player || !root.player.loopSupported)
            return;
        if (root.player.loopState === MprisLoopState.None)
            root.player.loopState = MprisLoopState.Playlist;
        else if (root.player.loopState === MprisLoopState.Playlist)
            root.player.loopState = MprisLoopState.Track;
        else
            root.player.loopState = MprisLoopState.None;
    }

    // --- Art + track ------------------------------------------------------
    Row {
        width: parent.width
        spacing: Tokens.space.m

        Rectangle {
            width: 120
            height: 120
            radius: Tokens.radius.card
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
                size: 42
            }
        }

        Column {
            width: parent.width - 120 - Tokens.space.m
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Text {
                width: parent.width
                text: root.player ? root.player.trackTitle : ""
                color: Theme.fg0
                font.family: "Adwaita Sans"
                font.pixelSize: 16
                font.weight: Font.DemiBold
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: root.player ? root.player.trackArtist : ""
                color: Theme.fg1
                font.family: "Adwaita Sans"
                font.pixelSize: 13
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: root.player ? root.player.trackAlbum : ""
                color: Theme.fg2
                font.family: "Adwaita Sans"
                font.pixelSize: 12
                elide: Text.ElideRight
            }
        }
    }

    // --- Progress ---------------------------------------------------------
    Column {
        width: parent.width
        spacing: 4

        Rectangle {
            id: track

            width: parent.width
            height: 6
            radius: 3
            color: Qt.rgba(Theme.fg0.r, Theme.fg0.g, Theme.fg0.b, 0.10)

            Rectangle {
                width: parent.width
                    * (root.length > 0 ? Math.min(1, root.pos / root.length) : 0)
                height: parent.height
                radius: 3
                color: Theme.gold
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

        Item {
            width: parent.width
            height: 14

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
        }
    }

    // --- Transport --------------------------------------------------------
    Item {
        width: parent.width
        height: 40

        Row {
            anchors.centerIn: parent
            spacing: Tokens.space.m

            Pressable {
                width: 32
                height: 32
                visible: root.player ? root.player.shuffleSupported : false

                onClicked: if (root.player && root.player.shuffleSupported)
                    root.player.shuffle = !root.player.shuffle

                Glyph {
                    anchors.centerIn: parent
                    glyph: "󰒝"
                    size: 15
                    tone: root.player && root.player.shuffle ? "active" : "normal"
                }
            }

            Pressable {
                width: 36
                height: 36

                onClicked: if (root.player && root.player.canGoPrevious)
                    root.player.previous()

                Glyph {
                    anchors.centerIn: parent
                    glyph: "󰙢"
                    size: 17
                    tone: root.player && root.player.canGoPrevious
                        ? "normal" : "disabled"
                }
            }

            Pressable {
                width: 40
                height: 40

                onClicked: if (root.player && root.player.canTogglePlaying)
                    root.player.togglePlaying()

                Glyph {
                    anchors.centerIn: parent
                    glyph: root.player && root.player.isPlaying ? "󰏤" : "󰐊"
                    size: 20
                    tone: "attention"
                }
            }

            Pressable {
                width: 36
                height: 36

                onClicked: if (root.player && root.player.canGoNext)
                    root.player.next()

                Glyph {
                    anchors.centerIn: parent
                    glyph: "󰒭"
                    size: 17
                    tone: root.player && root.player.canGoNext
                        ? "normal" : "disabled"
                }
            }

            Pressable {
                width: 32
                height: 32
                visible: root.player ? root.player.loopSupported : false

                onClicked: root.cycleLoop()

                Glyph {
                    anchors.centerIn: parent
                    glyph: root.player
                        && root.player.loopState === MprisLoopState.Track
                        ? "󰑘" : "󰑖"
                    size: 15
                    tone: root.player
                        && root.player.loopState !== MprisLoopState.None
                        ? "active" : "normal"
                }
            }
        }
    }
}
