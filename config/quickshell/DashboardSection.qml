// The system dashboard as a section of the control centre, laid out like the
// reference dots: four ring gauges (CPU, GPU, memory, swap) and, below, disks
// and network side by side.
//
// Read-only: the actions live in Resources' processes page and the session row.
// Processes and the 1 s sampling only run while the section is visible.
import Quickshell
import QtQuick

Item {
    id: root

    width: parent.width
    implicitHeight: body.implicitHeight

    onVisibleChanged: {
        Processes.active = visible;
        Resources.dashboardVisible = visible;
    }
    Component.onCompleted: {
        if (visible) {
            Processes.active = true;
            Resources.dashboardVisible = true;
        }
    }

    function bytes(v) {
        if (!isFinite(v) || v <= 0)
            return "0 B";
        if (v < 1024)
            return Math.round(v) + " B";
        if (v < 1048576)
            return (v / 1024).toFixed(1) + " KB";
        if (v < 1073741824)
            return (v / 1048576).toFixed(1) + " MB";
        return (v / 1073741824).toFixed(1) + " GB";
    }

    function rate(v) {
        return root.bytes(v) + "/s";
    }

    // One scale for both network series, from their own peak: a 2 KB/s hop and
    // a 40 KB/s one otherwise look identical.
    function netPeak() {
        let p = 1;
        const a = Resources.netRxHistory;
        const b = Resources.netTxHistory;
        for (let i = 0; i < a.length; ++i)
            p = Math.max(p, a[i]);
        for (let i = 0; i < b.length; ++i)
            p = Math.max(p, b[i]);
        return p;
    }

    function normalise(history) {
        const peak = root.netPeak();
        const out = [];
        for (let i = 0; i < history.length; ++i)
            out.push(history[i] / peak);
        return out;
    }

    // --- Pieces -----------------------------------------------------------
    component Card: Rectangle {
        id: card

        default property alias content: inner.data

        radius: Tokens.radius.card
        color: Qt.rgba(Theme.bg1.r, Theme.bg1.g, Theme.bg1.b, 0.88)

        Column {
            id: inner

            anchors.fill: parent
            anchors.margins: Tokens.space.m
            spacing: Tokens.space.xs
        }
    }

    // One gauge: the label above, the ring, and three lines inside it (a small
    // figure on top, the main value, a small one under it), as in the
    // reference.
    component Gauge: Item {
        id: gauge

        property string label: ""
        property real value: 0
        property string topText: ""
        property string mainText: ""
        property string bottomText: ""

        Card {
            anchors.fill: parent

            Column {
            width: parent.width
            spacing: 4

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: gauge.label
                color: Theme.fg0
                font.family: "Adwaita Sans"
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }

            Item {
                width: parent.width
                height: Math.min(parent.width, gauge.height - 52)

                Ring {
                    anchors.fill: parent
                    anchors.margins: 6
                    value: gauge.value
                    // The palette's one meaning for red: something is wrong.
                    fillColor: gauge.value >= 0.9 ? Theme.red : Theme.gold
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 0

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: gauge.topText !== ""
                        text: gauge.topText
                        color: Theme.fg2
                        font.family: "Adwaita Sans"
                        font.pixelSize: 10
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: gauge.mainText
                        color: Theme.fg0
                        font.family: "Adwaita Sans"
                        font.pixelSize: 22
                        font.weight: Font.DemiBold
                        font.features: ({ "tnum": 1 })
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: gauge.bottomText !== ""
                        text: gauge.bottomText
                        color: Theme.fg1
                        font.family: "Adwaita Sans"
                        font.pixelSize: 10
                        font.features: ({ "tnum": 1 })
                    }
                }
            }
            }
        }
    }

    component Title: Text {
        color: Theme.fg1
        font.family: "Adwaita Sans"
        font.pixelSize: 12
        font.weight: Font.DemiBold
    }

    component Bar: Item {
        id: bar

        property real value: 0
        property color fill: Theme.gold

        width: parent.width
        height: 6

        Rectangle {
            anchors.fill: parent
            radius: 3
            color: Theme.bg2
        }

        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, bar.value))
            height: parent.height
            radius: 3
            color: bar.fill
        }
    }

    Column {
        id: body

        width: parent.width
        spacing: 8

    // --- The four gauges --------------------------------------------------
    Row {
        id: gauges

        width: parent.width
        spacing: 8
        height: 190

        Gauge {
            width: (gauges.width - gauges.spacing * 3) / 4
            height: gauges.height

            label: "CPU"
            value: Resources.cpu
            topText: isNaN(Resources.tempC) ? "" : Math.round(Resources.tempC) + "\u00b0"
            mainText: Math.round(Resources.cpu * 100) + "%"
            bottomText: isNaN(Resources.cpuMHz)
                ? "" : (Resources.cpuMHz / 1000).toFixed(2) + " GHz"
        }

        Gauge {
            width: (gauges.width - gauges.spacing * 3) / 4
            height: gauges.height

            label: "GPU"
            value: isNaN(Resources.gpu) ? 0 : Resources.gpu
            topText: isNaN(Resources.tempC) ? "" : Math.round(Resources.tempC) + "\u00b0"
            mainText: isNaN(Resources.gpu) ? "—" : Math.round(Resources.gpu * 100) + "%"
            bottomText: isNaN(Resources.vramUsedGiB)
                ? "" : Resources.vramUsedGiB.toFixed(2) + " GiB"
        }

        Gauge {
            width: (gauges.width - gauges.spacing * 3) / 4
            height: gauges.height

            label: "Memory"
            value: Resources.memUsed
            topText: Resources.memUsedGiB.toFixed(2) + " GiB"
            mainText: Math.round(Resources.memUsed * 100) + "%"
            bottomText: Resources.memTotalGiB.toFixed(2) + " GiB"
        }

        Gauge {
            width: (gauges.width - gauges.spacing * 3) / 4
            height: gauges.height

            label: "Swap"
            value: Resources.swapTotalGiB > 0
                ? Resources.swapUsedGiB / Resources.swapTotalGiB : 0
            topText: Resources.swapUsedGiB.toFixed(2) + " GiB"
            mainText: Resources.swapTotalGiB > 0
                ? Math.round(100 * Resources.swapUsedGiB / Resources.swapTotalGiB) + "%"
                : "—"
            bottomText: Resources.swapTotalGiB.toFixed(2) + " GiB"
        }
    }

    // --- Disks + network ---------------------------------------------------
    Row {
        id: lower

        width: parent.width
        spacing: 8
        height: 226

        Card {
            width: (lower.width - lower.spacing) / 2
            height: lower.height

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: "Disks"
                color: Theme.fg0
                font.family: "Adwaita Sans"
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }

            Column {
                width: parent.width
                spacing: 10

                Repeater {
                    model: Resources.disks

                    delegate: Column {
                        id: diskRow

                        required property var modelData

                        width: parent.width
                        spacing: 3

                        Item {
                            width: parent.width
                            height: 16

                            Text {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: diskRow.modelData.mount
                                color: Theme.fg0
                                font.family: "Adwaita Sans"
                                font.pixelSize: 11
                            }

                            Text {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.bytes(diskRow.modelData.used) + " / "
                                    + root.bytes(diskRow.modelData.size)
                                color: Theme.fg1
                                font.family: "Adwaita Sans"
                                font.pixelSize: 11
                                font.features: ({ "tnum": 1 })
                            }
                        }

                        Bar {
                            value: diskRow.modelData.pct / 100
                            fill: diskRow.modelData.pct >= 90 ? Theme.red : Theme.gold
                        }
                    }
                }
            }
        }

        Card {
            width: (lower.width - lower.spacing) / 2
            height: lower.height


            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: "Network"
                color: Theme.fg0
                font.family: "Adwaita Sans"
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }

            Item {
                width: parent.width
                height: 118

                Sparkline {
                    anchors.fill: parent
                    highlighted: true
                    samples: root.normalise(Resources.netTxHistory)
                }

                Sparkline {
                    anchors.fill: parent
                    samples: root.normalise(Resources.netRxHistory)
                }
            }

            Item {
                width: parent.width
                height: 16

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.rate(root.netPeak())
                    color: Theme.fg2
                    font.family: "Adwaita Sans"
                    font.pixelSize: 9
                    font.features: ({ "tnum": 1 })
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    Row {
                        spacing: 4

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 6
                            height: 6
                            radius: 3
                            color: Theme.fg1
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Download"
                            color: Theme.fg1
                            font.family: "Adwaita Sans"
                            font.pixelSize: 10
                        }
                    }

                    Row {
                        spacing: 4

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 6
                            height: 6
                            radius: 3
                            color: Theme.gold
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Upload"
                            color: Theme.fg1
                            font.family: "Adwaita Sans"
                            font.pixelSize: 10
                        }
                    }
                }
            }

            Text {
                width: parent.width
                text: (Resources.netIface !== "" ? Resources.netIface : "offline")
                    + (Resources.netIp !== "" ? " · " + Resources.netIp : "")
                color: Theme.fg2
                font.family: "Adwaita Sans"
                font.pixelSize: 10
                elide: Text.ElideRight
            }
        }
    }
    }
}
