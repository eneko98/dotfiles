// The measurement HUD. Overlay-only and passive (no reserved space, no input
// mask). Frame timing comes from FrameProbe; system metrics from HudMetrics.
// Nothing runs here unless Config.hud is true. Toggle with SUPER+H or
// `qs ipc call bar hud toggle`.
import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: root

    anchors {
        top: true
        left: true
    }

    visible: Config.hud
    // The window must include the card's offset: a PanelWindow clips to its
    // own size, so `implicitHeight: card.height` with the card at y=46 cut
    // the last row off.
    implicitWidth: card.x + card.width + Tokens.space.s
    implicitHeight: card.y + card.height + Tokens.space.s
    color: "transparent"

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: Tokens.ns.hud
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}

    function frameRows() {
        const s = Perf.frameStats;
        const rows = [];
        for (const name in s) {
            const v = s[name];
            rows.push({ name: name, p50: v[0], p95: v[1], max: v[2] });
        }
        rows.sort(function (a, b) { return b.p95 - a.p95; });
        return rows.slice(0, 5);
    }

    HudMetrics {
        id: metrics
    }

    Item {
        id: card

        x: Tokens.space.s
        // Below the 38 px bar so the pills stay readable; this is an overlay
        // the user asked for, not something that should hide the clock.
        y: 46
        width: 294
        height: column.implicitHeight + Tokens.space.l * 2

        Surface {
            region: "panel"
            anchors.fill: parent
            level: 2
            radius: Tokens.radius.panel
        }

        Column {
            id: column

            x: Tokens.space.m
            y: Tokens.space.m
            width: parent.width - Tokens.space.m * 2
            spacing: Tokens.space.s

            Item {
                width: parent.width
                height: titleLabel.implicitHeight

                Text {
                    id: titleLabel
                    text: "PERFORMANCE"
                    color: Theme.fg1
                    font.family: "Adwaita Sans"
                    font.pixelSize: 12
                    font.bold: true
                }

                Text {
                    anchors.right: parent.right
                    text: "p50 / p95 / max (ms)"
                    color: Theme.fg2
                    font.family: "Adwaita Sans"
                    font.pixelSize: 10
                }
            }

            Repeater {
                model: root.frameRows()

                delegate: Item {
                    required property string name
                    required property real p50
                    required property real p95
                    required property real max

                    width: parent.width
                    height: nameLabel.implicitHeight

                    Text {
                        id: nameLabel
                        width: 100
                        text: name
                        color: p95 > 16.7 ? Theme.gold : Theme.fg1
                        font.family: "Adwaita Sans"
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }

                    Text {
                        anchors.right: parent.right
                        text: p50.toFixed(1) + " / " + p95.toFixed(1)
                            + " / " + max.toFixed(1)
                        color: p95 > 16.7 ? Theme.gold : Theme.fg0
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                        font.features: ({ "tnum": 1 })
                    }
                }
            }

            Rectangle {
                visible: root.frameRows().length > 0
                width: parent.width
                height: 1
                color: Qt.rgba(Theme.fg0.r, Theme.fg0.g, Theme.fg0.b, 0.08)
            }

            Text {
                visible: root.frameRows().length === 0
                text: "no frame drops"
                color: Theme.fg2
                font.family: "Adwaita Sans"
                font.pixelSize: 11
            }

            Text {
                text: "GPU  " + (metrics.gpuPct < 0 ? "—"
                        : Math.round(metrics.gpuPct) + "%")
                    + "   CPU " + (metrics.shellCpu < 0 ? "—"
                        : metrics.shellCpu.toFixed(1) + "%")
                    + "   PSS " + Math.round(metrics.pssMB) + " MiB"
                color: Theme.fg0
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 11
                font.features: ({ "tnum": 1 })
            }

            Text {
                text: "PSI " + metrics.psiPct.toFixed(2) + "%"
                    + "   zram " + metrics.zramOrigGiB.toFixed(1)
                    + " → " + metrics.zramUsedGiB.toFixed(1)
                    + (metrics.zramRatio > 0
                        ? " GiB (" + metrics.zramRatio.toFixed(1) + "×)"
                        : " GiB")
                color: Theme.fg1
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 11
                font.features: ({ "tnum": 1 })
            }

            Text {
                text: (metrics.tempC < 0 ? "—"
                        : metrics.tempC.toFixed(0) + " °C")
                    + "   " + (metrics.batteryStatus.indexOf("Discharg") === 0
                        ? metrics.powerW.toFixed(1) + " W"
                        : "AC")
                color: Theme.fg1
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 11
                font.features: ({ "tnum": 1 })
            }

            // GPU vs CPU decode: the video engine turns only when the driver
            // is decoding on the GPU; 0 % means software decoding.
            Text {
                text: "video " + (metrics.videoLoad < 0 ? "—"
                        : Math.round(metrics.videoLoad * 100) + "%")
                    + (metrics.videoApp !== "" && metrics.videoApp !== "-"
                        ? " · " + metrics.videoApp : "")
                color: metrics.videoLoad > 0.02 ? Theme.gold : Theme.fg2
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 11
                font.features: ({ "tnum": 1 })
            }
        }
    }
}
