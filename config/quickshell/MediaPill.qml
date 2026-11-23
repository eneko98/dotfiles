// The media pill. Two states:
//  - live: a player is playing (or paused with a title), shown as the reference
//    does -- a small round button with the play/pause glyph;
//  - stale: nothing is playing but the last track is remembered. It is "glyph +
//    title — artist" for three seconds after the shell starts, then it collapses
//    to the bare glyph: the title of a song that finished days ago is noise, but
//    the button is the way back into the bubble (and to resume Spotify).
//
// The last track is persisted in Config, so it survives a reboot.
import Quickshell
import Quickshell.Io
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
    readonly property bool shown: root.live || root.stale

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
    // Live and expired-stale are the same 38 px button; only the remembered
    // label makes it wider.
    width: root.live ? 38
        : root.stale ? (root.staleExpired ? 38 : staleRow.implicitWidth + 24)
        : 0
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
        if (root.player === null || root.player.trackTitle === "")
            return;

        const url = root.player.trackArtUrl;
        if (url === "" || artCopy.running) {
            // Nothing to keep (or a copy already in flight): the 3 s retry
            // below will pass again with whatever the metadata has then.
            Config.saveLastTrack(root.player.trackTitle,
                root.player.trackArtist, url);
            return;
        }

        // Remember OUR copy, not the source: Spotify's CDN links expire
        // (measured: the saved one was dead days later) and Firefox's MPRIS
        // art is a pid-named file that dies with the browser. Either way the
        // sleeve at rest fell back to the glyph. One durable file per track.
        artCopy.title = root.player.trackTitle;
        artCopy.artist = root.player.trackArtist;
        artCopy.url = url;
        artCopy.running = true;
    }

    Process {
        id: artCopy

        property string url: ""
        property string title: ""
        property string artist: ""

        // file:// becomes a cat, http(s) a curl; both land in the same file.
        // The URL is quoted for the shell; art URLs carry no quotes.
        command: ["sh", "-c",
            'mkdir -p "$HOME/.local/state/dotfiles/media" && '
            + (url.startsWith("http")
                ? 'curl -fsSL --max-time 8 "' + url + '"'
                : 'cat "' + url.replace(/^file:\/\//, "") + '"')
            + ' > "$HOME/.local/state/dotfiles/media/last-art.img"']

        stdout: StdioCollector { }

        onExited: function (code, status) {
            if (code === 0)
                Config.saveLastTrack(artCopy.title, artCopy.artist,
                    "file://" + Quickshell.env("HOME")
                    + "/.local/state/dotfiles/media/last-art.img");
            else
                // Keep the URL as the old code did: better a dead link at
                // rest than no memory of the cover at all.
                Config.saveLastTrack(artCopy.title, artCopy.artist, artCopy.url);
        }
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
            visible: root.stale && !root.staleExpired
            width: Math.min(implicitWidth, 220)
            text: root.staleLabel
            elide: Text.ElideRight
            color: Theme.fg2
            font.family: "Adwaita Sans"
            font.pixelSize: 11
        }
    }
}
