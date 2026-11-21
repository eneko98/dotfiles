// Synchronized lyrics for whatever is playing, read by the island and by the
// Today panel so both show the same line.
//
// MPRIS gives a position in seconds but only updates it a few times a second
// (Spotify is chattier than Firefox), so between notifications the position is
// interpolated from the last reading. The lookup itself is one Process per
// track: the helper caches both hits and misses.
pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import QtQuick

Singleton {
    id: root

    // Same pick as Media.qml: the first player actually playing, else the
    // first one with a title. Keeping the rule identical means the track the
    // island shows and the lyrics it shows belong to the same player.
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

    property bool enabled: true
    property var lines: []
    property int index: -1

    // A line is only worth showing while something plays: a paused player
    // keeps the last line, so the island can be read at a glance.
    readonly property bool hasLyrics: root.lines.length > 0
    readonly property bool playing: root.player !== null && root.player.isPlaying

    readonly property string current: root.index >= 0 && root.index < root.lines.length
        ? root.lines[root.index][1] : ""
    readonly property string previous: root.index > 0
        ? root.lines[root.index - 1][1] : ""
    readonly property string next: root.index >= 0 && root.index + 1 < root.lines.length
        ? root.lines[root.index + 1][1] : ""

    // Last position read from MPRIS and the wall clock at that moment.
    property real basePos: 0
    property real baseAt: 0

    function now() {
        if (root.player === null)
            return 0;
        if (!root.player.isPlaying)
            return root.basePos;
        return root.basePos + (Date.now() - root.baseAt) / 1000;
    }

    // Binary search over lines sorted by time: the last line that has begun.
    function locate(t) {
        let low = 0;
        let high = root.lines.length - 1;
        let found = -1;

        while (low <= high) {
            const mid = (low + high) >> 1;
            if (root.lines[mid][0] <= t) {
                found = mid;
                low = mid + 1;
            } else {
                high = mid - 1;
            }
        }

        return found;
    }

    function resync() {
        if (root.player === null)
            return;
        root.basePos = root.player.position;
        root.baseAt = Date.now();
    }

    function load() {
        root.lines = [];
        root.index = -1;
        if (!root.enabled || root.player === null || root.player.trackTitle === "")
            return;

        fetch.command = [
            Quickshell.env("HOME") + "/.config/hypr/scripts/lyrics.py",
            root.player.trackArtist || "",
            root.player.trackTitle,
            root.player.trackAlbum || "",
            String(root.player.length || 0)
        ];
        fetch.running = true;
    }

    onEnabledChanged: if (root.enabled) root.load()

    // A player that was already on a track when the shell started is not a
    // title change: load when the pick itself changes.
    onPlayerChanged: {
        root.load();
        root.resync();
    }

    Component.onCompleted: root.load()

    Connections {
        target: root.player

        function onTrackTitleChanged() {
            root.load();
            root.resync();
        }

        // A seek or a pause moves the position by more than interpolation
        // can follow.
        function onPositionChanged() {
            root.resync();
        }

        function onIsPlayingChanged() {
            root.resync();
        }

        // Some players learn the duration a moment after the title.
        function onLengthChanged() {
            if (root.lines.length === 0)
                root.load();
        }
    }

    Process {
        id: fetch

        command: []

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.lines = JSON.parse(text).lines || [];
                } catch (e) {
                    root.lines = [];
                }
                root.index = -1;
                root.resync();
            }
        }
    }

    // 100 ms is enough for a line that spans seconds, and cheap: it only reads
    // Date.now() and an array entry while something plays with lyrics.
    Timer {
        interval: 100
        repeat: true
        running: root.playing && root.hasLyrics
        triggeredOnStart: true

        onTriggered: {
            const at = root.locate(root.now() + 0.15);
            if (at !== root.index)
                root.index = at;
        }
    }
}
