// The vinyl widget: a record coming out of its sleeve.
//
// The bubble's media card is a control panel (seek, buttons, rows); this one is
// a poster. The album art is the sleeve, and the record behind it slides out
// and turns while the track plays, sliding back in when it pauses -- the state
// is the object, not a glyph. Below, the title (dimmed while paused, like the
// island) and one line of times. No buttons: clicking opens the bubble, which
// owns the controls.
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Widget {
    id: root

    widgetId: "vinyl"
    defaultRight: false
    cardW: 360
    cardH: 316

    // Same pick as the pill: the first player actually playing, else the first
    // with a title. A title is required (playerctld registers with nothing).
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

    readonly property bool live: player !== null
    readonly property string art: live && player.trackArtUrl !== ""
        ? player.trackArtUrl : Config.lastArt
    readonly property string title: live ? player.trackTitle : Config.lastTitle
    readonly property string artist: live ? player.trackArtist : Config.lastArtist

    // The record's position: MPRIS does not push ticks, so a timer reads it
    // while the card is on screen (the MediaCard lesson).
    property real pos: 0
    readonly property real len: live ? (player.length || 0) : 0

    onPlayerChanged: root.pos = live ? player.position : 0

    Timer {
        interval: 500
        running: root.visible && root.live
        repeat: true
        triggeredOnStart: true

        onTriggered: if (root.live)
            root.pos = root.player.position
    }

    function fmt(t) {
        if (isNaN(t) || t < 0)
            return "0:00";
        const m = Math.floor(t / 60);
        const s = Math.floor(t % 60);
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    // The record: behind the sleeve, sliding out while it plays. Resting it
    // peeks 36 px -- "there is a record here" -- and playing it owns 120.
    // A plain property (not readonly): the slide is what the Behavior animates.
    property real slide: (live && player.isPlaying) ? 120 : 36

    Vinyl {
        x: 20 + root.slide
        y: 20
        size: 200
        playing: root.live && root.player.isPlaying
        art: root.art
    }

    // The sleeve: the album art, square and cropped, with a fallback glyph
    // when there is no art at all.
    Item {
        x: 20
        y: 20
        width: 200
        height: 200

        Image {
            anchors.fill: parent
            visible: root.art !== ""
            source: root.art
            fillMode: Image.PreserveAspectCrop
        }

        Rectangle {
            anchors.fill: parent
            visible: root.art === ""
            color: Qt.rgba(Theme.bg2.r, Theme.bg2.g, Theme.bg2.b, 0.7)

            Text {
                anchors.centerIn: parent
                text: "󰎈"
                color: Theme.fg2
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 56
            }
        }

        // A sleeve edge, so the art reads as an object on the card.
        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(Theme.fg0.r, Theme.fg0.g, Theme.fg0.b, 0.10)
        }
    }

    // The text block, left-aligned with the sleeve.
    Column {
        x: 20
        y: 236
        width: 320
        spacing: 4

        Text {
            width: parent.width
            text: root.title !== "" ? root.title : "Nothing playing"
            elide: Text.ElideRight
            // Paused keeps the state but steps back, as the island does.
            color: root.live && root.player.isPlaying ? Theme.fg0 : Theme.fg1
            font.family: "Adwaita Sans"
            font.pixelSize: 14
            font.weight: Font.DemiBold
        }

        Text {
            width: parent.width
            text: root.artist
            visible: root.artist !== ""
            elide: Text.ElideRight
            color: Theme.fg1
            font.family: "Adwaita Sans"
            font.pixelSize: 11
        }
    }

    // One line of times and a bar that grows: the seek lives in the bubble,
    // this only says where the track is.
    Row {
        x: 20
        y: 288
        width: 320
        height: 12
        spacing: 10

        Text {
            width: 34
            text: root.fmt(root.pos)
            color: Theme.fg1
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 10
        }

        Item {
            width: parent.width - 34 - 44 - 20
            height: 3
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                anchors.fill: parent
                radius: 1
                color: Qt.rgba(Theme.fg0.r, Theme.fg0.g, Theme.fg0.b, 0.10)
            }

            Rectangle {
                width: parent.width * Math.max(0, Math.min(1,
                    root.len > 0 ? root.pos / root.len : 0))
                height: parent.height
                radius: 1
                color: Theme.gold
            }
        }

        Text {
            width: 34
            text: root.fmt(root.len)
            color: Theme.fg2
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 10
        }
    }

    // The record slides out over the same beat as the island's morphs.
    Behavior on slide {
        NumberAnimation {
            duration: Motion.medium
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.standard
        }
    }
}
