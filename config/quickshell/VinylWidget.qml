// The vinyl widget: a record coming out of its sleeve.
//
// The card never changes size. At rest the sleeve sits centred with equal
// air on both sides (the old design kept an empty dark column for a disc
// that was not coming out: that read as a bug). When the track plays, the
// sleeve slides LEFT and the disc slides RIGHT, symmetric, inside the same
// 280x280 frame; on pause the disc goes back in. The state is the object,
// not a glyph.
//
// The artwork crossfades: the new cover loads in the hidden of two stacked
// Images and, when it is Ready, they swap opacity. A failed load (an https
// cover with no network) leaves the previous art visible under the fallback.
// No clicks: the bubble owns every control.
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Widget {
    id: root

    widgetId: "vinyl"
    defaultRight: false
    cardW: 280
    cardH: 280

    // --- the player ---------------------------------------------------------
    // The first one actually playing, else the first with a title. playerctld
    // registers as a player and mirrors whatever is behind it: excluding it
    // keeps the widget from following a proxy.
    readonly property var player: {
        const ps = Mpris.players.values;
        let fallback = null;

        for (let i = 0; i < ps.length; ++i) {
            const p = ps[i];
            if ((p.dbusName || "").indexOf("playerctld") !== -1)
                continue;
            if (p.trackTitle === "")
                continue;
            if (p.isPlaying)
                return p;
            if (fallback === null)
                fallback = p;
        }

        return fallback;
    }

    readonly property bool live: player !== null
    readonly property bool playing: live && player.isPlaying
    readonly property string title: live ? player.trackTitle : Config.lastTitle
    readonly property string artist: live ? player.trackArtist
        : Config.lastArtist
    readonly property string artWanted: live && player.trackArtUrl !== ""
        ? player.trackArtUrl : Config.lastArt

    // --- the sleeve and the record -------------------------------------------
    // One value, 0 inside / 1 out, animated with a curve per direction: the
    // record leaves with decel (it settles out) and returns with accel (it
    // is pushed back in). A single Behavior could not have both.
    property real out: 0

    NumberAnimation {
        id: outGo

        target: root
        property: "out"
        to: 1
        duration: Motion.medium
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Motion.decel
    }

    NumberAnimation {
        id: outBack

        target: root
        property: "out"
        to: 0
        duration: Motion.medium
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Motion.accel
    }

    // ONE onPlayingChanged in the file: two handlers of the same signal do
    // not add up, they break the load ("Property value set multiple times").
    onPlayingChanged: {
        outGo.stop();
        outBack.stop();
        if (root.playing) {
            outGo.from = root.out;
            outGo.start();
        } else {
            outBack.from = root.out;
            outBack.start();
        }
        root.readPos();
    }

    // The record, BELOW the sleeve in z (declared first): it slides out from
    // behind it. The label is small (0.44): inside a sleeve, a big label
    // reads as a stamp. It only spins when the desktop is actually visible
    // (§ covered check) and reduced motion says no.
    Vinyl {
        x: root.sleeveX + 4 + 80 * root.out
        y: 20
        size: 160
        labelRatio: 0.44
        playing: root.playing && root.desktopSeen && !Motion.reduced
        art: root.artWanted
    }

    Item {
        id: sleeve

        x: root.sleeveX
        y: 16
        width: 168
        height: 168

        // The sleeve base is OPAQUE: the record sits right behind it, and a
        // translucent base let the disc bleed through the fallback (the
        // "weird cover" the user saw). The glyph lives under the images too:
        // a cover that loads covers it; one that is loading (or failed, like
        // an expired Spotify CDN link) shows it.
        Rectangle {
            anchors.fill: parent
            color: Theme.bg2

            Glyph {
                anchors.centerIn: parent
                glyph: "\uf001"
                size: 48
                tone: "disabled"
            }
        }

        // Two stacked covers; the new one loads in the hidden slot and, when
        // Ready, the opacities cross. artBroken hides both, so the fallback
        // underneath takes over.
        Image {
            id: imgA

            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 268
            sourceSize.height: 268
            asynchronous: true
            cache: true
            smooth: true
            mipmap: true
            visible: opacity > 0
            opacity: root.frontSlot === 0 && !root.artBroken
                && status === Image.Ready ? 1 : 0

            onStatusChanged: {
                if (status === Image.Ready)
                    root.artArrived(0, source);
                else if (status === Image.Error)
                    root.artFailed(source);
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: Motion.base
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Motion.standard
                }
            }
        }

        Image {
            id: imgB

            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 268
            sourceSize.height: 268
            asynchronous: true
            cache: true
            smooth: true
            mipmap: true
            visible: opacity > 0
            opacity: root.frontSlot === 1 && !root.artBroken
                && status === Image.Ready ? 1 : 0

            onStatusChanged: {
                if (status === Image.Ready)
                    root.artArrived(1, source);
                else if (status === Image.Error)
                    root.artFailed(source);
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: Motion.base
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Motion.standard
                }
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

    // Sleeve x: 56 centred at rest, 16 while playing. 56 - 40 = 16.
    readonly property real sleeveX: 56 - 40 * root.out

    // --- the art crossfade ---------------------------------------------------
    property int frontSlot: 0
    property bool artBroken: root.artWanted === ""

    function loadArt() {
        root.artBroken = root.artWanted === "";
        if (root.artBroken)
            return;
        (root.frontSlot === 0 ? imgB : imgA).source = root.artWanted;
    }

    onArtWantedChanged: root.loadArt()
    Component.onCompleted: root.loadArt()

    function artArrived(slot, url) {
        // A stale reply (the art changed again mid-load) must not flip.
        if (url !== root.artWanted)
            return;
        root.frontSlot = slot;
        root.artBroken = false;
    }

    function artFailed(url) {
        if (url !== root.artWanted)
            return;
        root.artBroken = true;
    }

    // --- the text -------------------------------------------------------------
    Text {
        x: 16
        y: 200
        width: 248
        height: 20
        horizontalAlignment: Text.AlignHCenter
        text: root.title !== "" ? root.title : "Nothing playing"
        elide: Text.ElideRight
        // Paused keeps the state but steps back, as the island does.
        color: root.playing ? Theme.fg0 : Theme.fg1
        font.family: "Adwaita Sans"
        font.pixelSize: 15
        font.weight: Font.DemiBold
        renderType: Text.QtRendering
        textFormat: Text.PlainText
    }

    Text {
        x: 16
        y: 222
        width: 248
        height: 16
        horizontalAlignment: Text.AlignHCenter
        text: root.artist
        visible: root.artist !== ""
        elide: Text.ElideRight
        color: Theme.fg1
        font.family: "Adwaita Sans"
        font.pixelSize: 12
        renderType: Text.QtRendering
        textFormat: Text.PlainText
    }

    // --- the times ------------------------------------------------------------
    // The one place a duration is not a Motion token: it is the data's own
    // period. Linear + glide = the reading interval makes the bar advance
    // continuously from one tick per second, without JS per frame.
    readonly property int pollMs: 1000

    property real pos: 0
    property bool smoothProgress: true
    readonly property real len: live ? (player.length || 0) : 0

    function readPos() {
        root.smoothProgress = false;
        root.pos = root.live ? root.player.position : 0;
    }

    onTitleChanged: root.readPos()
    onDesktopSeenChanged: if (root.desktopSeen) root.readPos()

    Timer {
        interval: root.pollMs
        running: root.visible && root.playing && root.desktopSeen
        repeat: true
        triggeredOnStart: true

        onTriggered: {
            const p = root.player.position;
            // A seek (or the covered-desktop gap) jumps: not a glide.
            root.smoothProgress = Math.abs(p - root.pos) < 2.5;
            root.pos = p;
        }
    }

    function fmt(t) {
        if (isNaN(t) || t < 0)
            return "0:00";
        const m = Math.floor(t / 60);
        const s = Math.floor(t % 60);
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    Text {
        x: 16
        y: 250
        width: 40
        height: 14
        visible: root.live
        text: root.fmt(root.pos)
        color: Theme.fg1
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 11
        renderType: Text.QtRendering
        textFormat: Text.PlainText
    }

    // The card's accent: the only gold in it.
    Meter {
        x: 64
        y: 255
        width: 152
        visible: root.live && root.len > 0
        value: root.len > 0 ? root.pos / root.len : NaN
        fill: Theme.gold
        linear: true
        glide: root.pollMs
        animated: root.smoothProgress && root.playing
    }

    Text {
        x: 224
        y: 250
        width: 40
        height: 14
        horizontalAlignment: Text.AlignRight
        visible: root.live
        text: root.fmt(root.len)
        color: Theme.fg1
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 11
        renderType: Text.QtRendering
        textFormat: Text.PlainText
    }

    // Nothing playing: the remembered track, and one quiet line instead of
    // the times.
    Text {
        x: 16
        y: 250
        width: 248
        height: 14
        horizontalAlignment: Text.AlignHCenter
        visible: !root.live && root.title !== ""
        text: "Last played"
        color: Theme.fg1
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 11
        renderType: Text.QtRendering
    }
}
