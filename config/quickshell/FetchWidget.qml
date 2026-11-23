// The fetch card, alive: the terminal's fastfetch as a designed card.
//
// Structure (design doc F-A): WHO the machine is on top (logo, user@host, the
// identity line, the uptime with its one neon dot), then a rule, then the
// four rows that never change, then the four that move -- each with its
// percentage in a fixed right-hand column and a Meter under the text, so the
// numbers can be scanned in one pass.
//
// Three separate binding sources on purpose: the static block depends on
// nothing alive, the live block on Resources (a tick rewrites ten texts, not
// the whole model), and the uptime has a binding of its own. Fixed-width
// figures keep every neighbour still between ticks.
import QtQuick
import Quickshell

Widget {
    id: root

    widgetId: "fetch"
    cardW: 344
    cardH: 312

    // While the card is hidden there is nothing to feed: the disk reader
    // stops, and Resources already pauses its own extra timers.
    onVisibleChanged: SystemInfo.watched = root.visible

    // --- WHO: the header --------------------------------------------------
    // The tinted Arch mark (gen-theme.py painted it with the accent: the
    // card's one piece of gold). 48 base px; sourceSize is the maximum the
    // zoom can ask for, so it never stretches.
    Image {
        x: 16
        y: 16
        width: 48
        height: 48
        source: "file://" + Quickshell.env("HOME")
            + "/.config/fastfetch/logo.png"
        fillMode: Image.PreserveAspectFit
        sourceSize.width: 80
        sourceSize.height: 80
        asynchronous: true
        smooth: true
        mipmap: true
    }

    Row {
        id: titleRow

        x: 88
        y: 21

        Text {
            id: titleText
            text: SystemInfo.user
            color: Theme.fg0
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 14
            font.weight: Font.DemiBold
            renderType: Text.QtRendering
            textFormat: Text.PlainText
        }

        Text {
            text: "@"
            color: Theme.fg2
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 14
            font.weight: Font.DemiBold
            renderType: Text.QtRendering
        }

        Text {
            text: SystemInfo.host
            color: Theme.fg0
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 14
            font.weight: Font.DemiBold
            renderType: Text.QtRendering
            textFormat: Text.PlainText
        }
    }

    // The identity line: distro, arch and the chip. The chip moves up here so
    // the CPU row below carries only live data.
    Text {
        x: 88
        y: 43
        width: 240
        height: 16
        text: SystemInfo.distro + " · " + SystemInfo.arch + " · "
            + root.cpuShort()
        elide: Text.ElideRight
        color: Theme.fg1
        font.family: "Adwaita Sans"
        font.pixelSize: 12
        renderType: Text.QtRendering
        textFormat: Text.PlainText
    }

    // The uptime, right-aligned, with the card's single neon point: the
    // fetch's "this is alive" marker. Baseline-aligned with the title.
    Row {
        id: uptimeRow

        x: 328 - width
        y: titleRow.y + titleText.y + titleText.baselineOffset
            - uptimeText.baselineOffset
        spacing: 6

        Rectangle {
            width: 6
            height: 6
            radius: 3
            color: Theme.teal
            y: (uptimeText.height - height) / 2
        }

        Text {
            id: uptimeText
            text: root.upFmt(Math.floor(SystemInfo.upSec / 60))
            color: Theme.fg1
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 12
            renderType: Text.QtRendering
            textFormat: Text.PlainText
        }
    }

    // The rule: the header ends, the data begins.
    Rectangle {
        x: 16
        y: 72
        width: 312
        height: 1
        color: Qt.rgba(Theme.fg0.r, Theme.fg0.g, Theme.fg0.b, 0.08)
    }

    // --- WHAT NEVER CHANGES ----------------------------------------------
    Repeater {
        model: root.staticRows.length

        delegate: Item {
            required property int index

            y: 80 + 20 * index
            width: parent.width
            height: 16

            Text {
                x: 16
                width: 72
                text: root.staticRows[index].k
                color: Theme.fg1
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                renderType: Text.QtRendering
            }

            // The value column is 240 px MINUS the suffix's own width: the
            // suffix follows the Text, so a full-width value pushed it to the
            // card's edge ("· pacman" hung outside, measured on screen).
            TextMetrics {
                id: suffixMetrics
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                text: root.staticRows[index].suffix
            }

            Row {
                x: 88

                Text {
                    width: 240 - suffixMetrics.width
                    text: root.staticRows[index].v
                    elide: Text.ElideRight
                    color: Theme.fg0
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    renderType: Text.QtRendering
                    textFormat: Text.PlainText
                }

                Text {
                    text: root.staticRows[index].suffix
                    visible: root.staticRows[index].suffix !== ""
                    color: Theme.fg1
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    renderType: Text.QtRendering
                }
            }
        }
    }

    // --- WHAT MOVES -------------------------------------------------------
    Repeater {
        model: root.liveRows.length

        delegate: Item {
            id: liveRow

            required property int index
            readonly property var row: root.liveRows[index]

            y: 176 + 32 * index
            width: parent.width
            height: 32

            Text {
                x: 16
                width: 72
                text: liveRow.row.k
                color: Theme.fg1
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                renderType: Text.QtRendering
            }

            // The detail is runs, not one string, so the temperature can go
            // red alone. The outer delegate has an id: the inner one reaches
            // its row through it, and its own index stays unshadowed.
            Row {
                x: 88

                Repeater {
                    model: liveRow.row.parts.length

                    delegate: Text {
                        id: part

                        required property int index

                        text: liveRow.row.parts[part.index].t
                        color: liveRow.row.parts[part.index].sep
                            ? Theme.fg2
                            : liveRow.row.parts[part.index].hot
                                ? Theme.red : Theme.fg1
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        font.weight: liveRow.row.parts[part.index].hot
                            ? Font.DemiBold : Font.Normal
                        renderType: Text.QtRendering
                        textFormat: Text.PlainText
                    }
                }
            }

            // The percentage is the headline figure: a fixed-width column
            // at the right edge, so all four scan in one pass and no tick
            // moves its neighbours.
            Text {
                x: 288
                y: 0
                width: 40
                horizontalAlignment: Text.AlignRight
                text: liveRow.row.pct
                color: Theme.fg0
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                renderType: Text.QtRendering
                textFormat: Text.PlainText
            }

            // The bar belongs to its row: 5 px under the text, 8 above the
            // next. fg1, not the accent -- the card's gold is the logo.
            Meter {
                x: 88
                y: 21
                width: 240
                value: liveRow.row.bar
            }
        }
    }

    // --- data --------------------------------------------------------------
    readonly property var staticRows: [
        { k: "Kernel", v: SystemInfo.kernel.replace(/^Linux /, ""),
            suffix: "" },
        { k: "WM", v: SystemInfo.wm, suffix: "" },
        { k: "Shell", v: SystemInfo.shell, suffix: "" },
        { k: "Packages", v: String(SystemInfo.packages), suffix: " · pacman" }
    ]

    readonly property bool tempHot: !isNaN(Resources.tempC)
        && Resources.tempC >= 85

    readonly property var liveRows: [
        {
            k: "CPU",
            parts: [
                { t: root.ghz(Resources.cpuMHz), sep: false, hot: false },
                { t: " · ", sep: true, hot: false },
                { t: root.temp(Resources.tempC), sep: false, hot: root.tempHot }
            ],
            pct: root.pct(Resources.cpu),
            bar: Resources.cpu
        },
        {
            k: "GPU",
            parts: [{ t: root.gpuName(), sep: false, hot: false }],
            pct: root.pct(Resources.gpu),
            bar: Resources.gpu
        },
        {
            k: "Memory",
            parts: [{
                t: Resources.memUsedGiB.toFixed(1) + " / "
                    + Resources.memTotalGiB.toFixed(1) + " GiB",
                sep: false, hot: false
            }],
            pct: root.pct(Resources.memUsed),
            bar: Resources.memUsed
        },
        {
            k: "Disk",
            parts: [{ t: root.diskDetail(), sep: false, hot: false }],
            pct: root.pct(root.diskFrac()),
            bar: root.diskFrac()
        }
    ]

    // --- formatting ---------------------------------------------------------
    // Fixed widths: in a monospace font a padded string never moves the rest
    // of the line, which is what keeps the card still between ticks.
    function pct(frac) {
        return isNaN(frac)
            ? "   —" : String(Math.round(frac * 100)).padStart(3, " ") + "%";
    }

    function ghz(mhz) {
        return isNaN(mhz) ? "—" : (mhz / 1000).toFixed(1) + " GHz";
    }

    function temp(c) {
        return isNaN(c) ? "—" : String(Math.round(c)).padStart(2, " ") + "°C";
    }

    function upFmt(min) {
        const d = Math.floor(min / 1440);
        const h = Math.floor((min % 1440) / 60);
        const m = min % 60;
        return d > 0 ? d + "d " + String(h).padStart(2, "0") + "h"
            : h + "h " + String(m).padStart(2, "0") + "m";
    }

    // The marketing model name ("AMD Ryzen 5 3500U with Radeon Vega Mobile
    // Gfx") split into its two usable pieces.
    function cpuShort() {
        if (SystemInfo.cpuModel === "")
            return "";
        return SystemInfo.cpuModel.replace(/^AMD /, "")
            .replace(/ with Radeon.*$/, "");
    }

    function gpuName() {
        const m = SystemInfo.cpuModel.match(/Radeon\s+\S+/);
        return m !== null ? m[0] : "GPU";
    }

    function diskFrac() {
        return SystemInfo.disk.total > 0
            ? SystemInfo.disk.used / SystemInfo.disk.total : NaN;
    }

    function diskDetail() {
        return SystemInfo.disk.total > 0
            ? (SystemInfo.disk.used / Math.pow(1024, 3)).toFixed(1) + " / "
                + (SystemInfo.disk.total / Math.pow(1024, 3)).toFixed(1)
                + " GiB"
            : "—";
    }
}
