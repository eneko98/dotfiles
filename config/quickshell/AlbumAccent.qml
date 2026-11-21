// The shell accent follows the album art while something plays.
//
// The chain is URL -> curl into the cache -> ColorQuantizer -> our own pick.
// The pick only accepts a colour that reads on the bar background (contrast
// 8:1 against bg1) and is not the alarm hue, because red keeps its single
// meaning. No valid candidate means the wallpaper accent stays: a photo with
// no colours should not tint the desktop grey.
//
// This is a Scope, not a singleton: a singleton cannot read another singleton
// by name here (measured), and the point is to write into Theme.gold.
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import QtQuick

Scope {
    id: root

    // Same pick as Media.qml and Lyrics.qml: first playing, else first with a
    // title. Three copies of six lines is worse than a wrong accent, but they
    // must not disagree, so keep the rule identical.
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

    readonly property string artUrl: root.player ? root.player.trackArtUrl : ""
    readonly property bool active: root.player !== null && root.player.isPlaying
        && root.artUrl !== ""

    // Where covers are cached: one file per art URL.
    readonly property string cacheDir: (Quickshell.env("XDG_CACHE_HOME")
        || (Quickshell.env("HOME") + "/.cache")) + "/dotfiles/art"

    // djb2 over the URL: short, stable and no crypto needed.
    function hashPath(url) {
        let hash = 5381;
        for (let i = 0; i < url.length; ++i)
            hash = ((hash * 33) ^ url.charCodeAt(i)) >>> 0;
        return root.cacheDir + "/" + String(hash) + ".jpg";
    }

    // The file being downloaded or just downloaded. A normal property, not a
    // binding: reading a binding right after the signal that dirties it can
    // still give the old value here (measured: artPath read as "" inside
    // onArtUrlChanged, one tick before it evaluated).
    property string pendingArt: ""

    // `var` so "no accent" is null and not a colour that could be mistaken for
    // one: transparent black is a valid colour value.
    readonly property var picked: {
        if (!root.active || quant.colors.length === 0)
            return null;
        return root.pick(quant.colors);
    }

    function relLum(c) {
        const f = function (v) {
            return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
        };
        return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b);
    }

    function contrast(a, b) {
        const la = root.relLum(a);
        const lb = root.relLum(b);
        return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05);
    }

    function pick(colors) {
        const alarmHue = Theme.red.hsvHue;
        let best = null;
        let bestScore = -1;

        for (let i = 0; i < colors.length; ++i) {
            const c = colors[i];
            if (c.hsvSaturation < 0.25)
                continue;
            // Keep red meaning "something is wrong".
            const dh = Math.abs(c.hsvHue - alarmHue);
            if (Math.min(dh, 1 - dh) < 0.07)
                continue;
            const score = c.hsvSaturation * Math.sqrt(c.hslLightness);
            if (score > bestScore) {
                best = c;
                bestScore = score;
            }
        }

        if (best === null)
            return null;

        // Lift it until it reads on the bar, never change its hue: the point is
        // that the colour comes from the cover.
        let out = best;
        for (let i = 0; i < 20 && root.contrast(out, Theme.bg1) < 8; ++i)
            out = Qt.hsla(out.hslHue, out.hslSaturation,
                          Math.min(1, out.hslLightness + 0.04), 1);

        return root.contrast(out, Theme.bg1) >= 8 ? out : null;
    }

    function download() {
        if (root.artUrl === "")
            return;
        root.pendingArt = root.hashPath(root.artUrl);
        // -s skips a file that is already there, so a repeat track costs no
        // network at all.
        fetch.command = ["sh", "-c",
            'mkdir -p "$1" && [ -s "$2" ] || curl -fsSL "$3" -o "$2"',
            "sh", root.cacheDir, root.pendingArt, root.artUrl];
        fetch.running = true;
    }

    // The cover may already be up when the shell starts; that is not a change.
    Component.onCompleted: root.download()
    onArtUrlChanged: root.download()

    Process {
        id: fetch

        onExited: function (code) {
            // ColorQuantizer wants a URL with a scheme: a bare path loads and
            // reports zero colours (measured).
            if (code === 0 && root.pendingArt !== "")
                quant.source = "file://" + root.pendingArt;
        }
    }

    ColorQuantizer {
        id: quant

        // 2^4 = 16 candidates: enough for an accent, cheap to compute.
        depth: 4
        rescaleSize: 64
    }

    Binding {
        target: Theme
        property: "gold"
        value: root.picked === null ? Theme.goldBase : root.picked
        restoreMode: Binding.RestoreNone
    }
}
