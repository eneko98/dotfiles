// What the island shows when something is playing: a play/pause glyph, the
// peak bars, and the current lyric line (or the track, elided to a fixed width
// so a long title cannot take over the bar).
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
import Quickshell.Services.Pipewire
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

    // While there are lyrics, the line replaces the track label: the song is
    // one hover away in Today, and a line that moves is the point of this.
    readonly property bool withLyrics: active && Lyrics.hasLyrics
        && Lyrics.current !== ""

    readonly property string label: {
        if (root.player === null)
            return "";

        if (root.withLyrics)
            return Lyrics.current;

        const title = root.player.trackTitle || "Unknown title";
        const artist = root.player.trackArtist;

        return artist === "" ? title : title + " — " + artist;
    }

    // The default output, not the player's own stream: Spotify publishes its
    // node without channel positions (Pipewire calls them Unknown) and the
    // peak monitor refuses it with "missing channels present in capture
    // stream" (measured). The sink has real Left/Right channels, so the bars
    // follow the output; anything else making sound rides along, which is
    // only visible while a player is up anyway.
    readonly property var peakNode: Pipewire.defaultAudioSink

    // Whether the cursor is over the island; BarTiers feeds this in. The peak
    // monitor is expensive -- leaving it on while music plays cost ~8 % of a
    // core, and the cost is opening and closing the capture stream, not
    // listening to it (measured: one cycle per second was 9 %, one per four
    // seconds 3 %, i.e. the same as off) -- so it only runs while the bars can
    // actually be looked at.
    property bool hovered: false

    readonly property bool peaksWanted: root.visible && root.hovered
        && root.player !== null && root.player.isPlaying

    visible: root.active

    PwNodePeakMonitor {
        id: peaks

        node: root.peakNode
        enabled: root.peaksWanted
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        // The MDI glyph's visual box sits about 2 px above the text's at this
        // size; nudge it down so the triangle reads centred next to the title.
        anchors.verticalCenterOffset: 1
        text: root.player && root.player.isPlaying ? "󰏤" : "󰐊"
        color: Theme.fg1
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 15

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: if (root.player && root.player.canTogglePlaying)
                root.player.togglePlaying()
        }
    }

    Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        visible: peaks.enabled

        Repeater {
            model: 2

            Rectangle {
                id: bar

                required property int index

                // A normal property, animated: a Behavior on a readonly one is
                // not reliable (measured with the slider). With the monitor off
                // the bars rest as thin dashes, so the island keeps its width.
                property real shown: peaks.enabled
                    ? Math.max(0.15, peaks.peaks[bar.index] || 0) : 0

                Behavior on shown {
                    NumberAnimation { duration: 90 }
                }

                width: 3
                height: 14
                radius: 1.5
                color: Theme.gold

                // Scale instead of height: a transform does not relayout.
                transform: Scale {
                    origin.y: bar.height
                    yScale: bar.shown
                }
            }
        }

        // Separates the bars from the line the way the island's own divider
        // separates media from the clock.
        Rectangle {
            width: 1
            height: 12
            color: Theme.bg2
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    Text {
        id: labelText

        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(implicitWidth, root.withLyrics ? 250 : 200)
        text: root.label
        color: Theme.fg1
        font.family: "Adwaita Sans"
        font.pixelSize: 11
        elide: Text.ElideRight

        // A line change is a small event, not a page turn: a quick fade from
        // 40 % keeps the eye on the clock instead of on the text.
        NumberAnimation {
            id: lineFade
            target: labelText
            property: "opacity"
            from: 0.4
            to: 1
            duration: Motion.fast
        }

        onTextChanged: if (root.withLyrics)
            lineFade.restart()
    }
}
