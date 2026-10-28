// The system dashboard: a dedicated panel (centred, read-only) with the slow
// picture the bar cannot show -- CPU + frequency + load, memory + zram,
// disks, network rates and the top processes. The actions stay in the System
// panel (Processes page, session row), so nothing here changes system state.
//
// Processes samples only while this is open: `Processes.active` follows
// `visible`, and the first rows appear on the second 2 s tick.
import Quickshell
import QtQuick

Popup {
    id: root

    panelWidth: 740
    centerVertically: true

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

    // --- Pieces -----------------------------------------------------------
    component Card: Rectangle {
        id: card

        default property alias content: inner.data

        width: parent.width
        implicitHeight: inner.implicitHeight + Tokens.space.m * 2
        radius: Tokens.radius.card
        color: Qt.rgba(Theme.bg1.r, Theme.bg1.g, Theme.bg1.b, 0.88)

        Column {
            id: inner
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Tokens.space.m
            spacing: Tokens.space.xs
        }
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

    component Title: Text {
        color: Theme.fg1
        font.family: "Adwaita Sans"
        font.pixelSize: 11
        font.weight: Font.DemiBold
    }

    // --- Header -----------------------------------------------------------
    Item {
        width: parent.width
        height: 24

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "System"
            color: Theme.fg0
            font.family: "Adwaita Sans"
            font.pixelSize: 15
            font.weight: Font.DemiBold
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: isNaN(Resources.tempC) ? "" : Math.round(Resources.tempC) + " °C"
            color: Theme.fg2
            font.family: "Adwaita Sans"
            font.pixelSize: 11
            font.features: ({ "tnum": 1 })
        }
    }

    Row {
        spacing: Tokens.space.l

        // --- Left: CPU, memory, disks -----------------------------------
        Column {
            width: 340
            spacing: 12

            Card {
                Item {
                    width: parent.width
                    height: 28

                    Title {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "CPU"
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: Math.round(Resources.cpu * 100) + "%"
                        color: Resources.alert === "cpu" || Resources.alertCritical
                            ? Theme.red : Theme.fg0
                        font.family: "Adwaita Sans"
                        font.pixelSize: 22
                        font.weight: Font.Bold
                        font.features: ({ "tnum": 1 })
                    }
                }

                Sparkline {
                    width: parent.width
                    height: 64
                    samples: Resources.cpuHistory
                    highlighted: Resources.alert === "cpu" || Resources.alertCritical
                }

                Text {
                    width: parent.width
                    text: (isNaN(Resources.cpuMHz)
                            ? "—"
                            : (Resources.cpuMHz / 1000).toFixed(2) + " GHz")
                        + "   Load " + Resources.load1.toFixed(2)
                        + " · " + Resources.load5.toFixed(2)
                        + " · " + Resources.load15.toFixed(2)
                    color: Theme.fg1
                    font.family: "Adwaita Sans"
                    font.pixelSize: 11
                    font.features: ({ "tnum": 1 })
                }
            }

            Card {
                Item {
                    width: parent.width
                    height: 20

                    Title {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Memory"
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: Resources.memUsedGiB.toFixed(1) + " / "
                            + Resources.memTotalGiB.toFixed(1) + " GB"
                        color: Theme.fg0
                        font.family: "Adwaita Sans"
                        font.pixelSize: 12
                        font.features: ({ "tnum": 1 })
                    }
                }

                Bar {
                    value: Resources.memUsed
                    fill: Resources.alert === "mem" || Resources.alertCritical
                        ? Theme.red : Theme.gold
                }

                Text {
                    width: parent.width
                    text: "zram " + Resources.swapUsedGiB.toFixed(1) + " / "
                        + Resources.swapTotalGiB.toFixed(1) + " GB"
                    color: Theme.fg1
                    font.family: "Adwaita Sans"
                    font.pixelSize: 11
                    font.features: ({ "tnum": 1 })
                }
            }

            Card {
                Title {
                    text: "Disks"
                }

                Repeater {
                    model: Resources.disks

                    delegate: Column {
                        id: diskRow

                        required property var modelData

                        width: parent.width
                        spacing: 3

                        Item {
                            width: parent.width
                            height: 18

                            Text {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: diskRow.modelData.mount
                                color: Theme.fg0
                                font.family: "Adwaita Sans"
                                font.pixelSize: 12
                            }

                            Text {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: diskRow.modelData.pct + "% · "
                                    + root.bytes(diskRow.modelData.used) + " / "
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

        // --- Right: network, processes ----------------------------------
        Column {
            width: 340
            spacing: 12

            Card {
                Item {
                    width: parent.width
                    height: 20

                    Title {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Network"
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: Resources.netIface !== "" ? Resources.netIface : "offline"
                        color: Theme.fg2
                        font.family: "Adwaita Sans"
                        font.pixelSize: 11
                    }
                }

                Text {
                    width: parent.width
                    text: Resources.netIp !== "" ? Resources.netIp : "No address"
                    color: Theme.fg0
                    font.family: "Adwaita Sans"
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }

                Item {
                    width: parent.width
                    height: 18

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "↓ " + root.rate(Resources.netRxRate)
                        color: Theme.fg0
                        font.family: "Adwaita Sans"
                        font.pixelSize: 12
                        font.features: ({ "tnum": 1 })
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: "↑ " + root.rate(Resources.netTxRate)
                        color: Theme.fg0
                        font.family: "Adwaita Sans"
                        font.pixelSize: 12
                        font.features: ({ "tnum": 1 })
                    }
                }

                Text {
                    width: parent.width
                    text: "Total ↓ " + root.bytes(Resources.netRxTotal)
                        + " · ↑ " + root.bytes(Resources.netTxTotal)
                    color: Theme.fg2
                    font.family: "Adwaita Sans"
                    font.pixelSize: 11
                    font.features: ({ "tnum": 1 })
                }
            }

            Card {
                Item {
                    width: parent.width
                    height: 20

                    Title {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Processes"
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: "top 5"
                        color: Theme.fg2
                        font.family: "Adwaita Sans"
                        font.pixelSize: 11
                    }
                }

                Repeater {
                    model: Processes.rows.slice(0, 5)

                    delegate: Item {
                        required property var modelData

                        width: parent.width
                        height: 20

                        Text {
                            anchors.left: parent.left
                            anchors.right: cpuLabel.left
                            anchors.rightMargin: Tokens.space.s
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.name
                            color: Theme.fg0
                            font.family: "Adwaita Sans"
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }

                        Text {
                            id: cpuLabel
                            anchors.right: memLabel.left
                            anchors.rightMargin: Tokens.space.s
                            anchors.verticalCenter: parent.verticalCenter
                            text: Math.round(modelData.cpu * 100) + "%"
                            color: Theme.fg1
                            font.family: "Adwaita Sans"
                            font.pixelSize: 11
                            font.features: ({ "tnum": 1 })
                        }

                        Text {
                            id: memLabel
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.bytes(modelData.rssBytes)
                            color: Theme.fg1
                            font.family: "Adwaita Sans"
                            font.pixelSize: 11
                            font.features: ({ "tnum": 1 })
                        }
                    }
                }

                Text {
                    visible: Processes.rows.length === 0
                    text: "Sampling…"
                    color: Theme.fg2
                    font.family: "Adwaita Sans"
                    font.pixelSize: 11
                }
            }
        }
    }
}
