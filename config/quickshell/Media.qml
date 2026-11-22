// What the island shows when something is playing: a play/pause glyph, the
// spectrum, and the current lyric line (or the track, elided to a fixed width
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
import Quickshell.Io
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

    // The spectrum: cava's FFT over the default output's monitor, in raw mode
    // (one line per frame, eight values 0..1000 separated by ';'). This
    // replaced PwNodePeakMonitor, which only knows one value per channel (two
    // bars, no bands) and cost as much while it was on.
    //
    // `bands` holds 0..1 heights; when cava is not running it stays at rest.
    property var bands: [0, 0, 0, 0, 0, 0, 0, 0]

    readonly property bool spectrumWanted: root.visible
        && root.player !== null && root.player.isPlaying

    visible: root.active

    // A `running:` binding on a Process is unreliable: Quickshell writes the
    // property when it starts and the binding does not come back (measured
    // with bt-agent). Start and stop are imperative here.
    function updateSpectrum() {
        if (root.spectrumWanted === cava.running)
            return;

        cava.running = root.spectrumWanted;
        if (!root.spectrumWanted)
            root.bands = [0, 0, 0, 0, 0, 0, 0, 0];
    }

    onSpectrumWantedChanged: root.updateSpectrum()
    Component.onCompleted: root.updateSpectrum()

    Process {
        id: cava

        command: ["cava", "-p", Quickshell.env("HOME") + "/.config/cava/config"]

        stdout: SplitParser {
            onRead: function (line) {
                const parts = line.split(";");
                const out = [];

                for (let i = 0; i < parts.length && out.length < 8; ++i) {
                    const value = parseInt(parts[i]);
                    if (!isNaN(value))
                        out.push(Math.min(1, value / 1000));
                }

                if (out.length === 8)
                    root.bands = out;
            }
        }
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
        // Shown while there is a player, not only while cava runs: otherwise
        // the island would shrink on every pause. With cava stopped the bars
        // rest as thin dashes.
        visible: root.active

        Repeater {
            model: 8

            Rectangle {
                id: bar

                required property int index

                // cava already smooths its own fall, so this is a plain
                // binding, no Behavior: animating eight bars twenty times a
                // second cost more than the FFT did (measured 13.8 % of a core
                // with the animation, 6.7 % without). 0.12 is the resting
                // height, so a silent band still shows a dash.
                property real shown: Math.max(0.12, root.bands[bar.index] || 0)

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
