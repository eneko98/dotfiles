// Resources: three 40px rows (name, 140x20 sparkline, tabular value) plus a
// secondary line with load and zram swap, and the way into ProcessesPage.
// The values paint red only while their alert is lit; the numbers are
// otherwise fg0. Sampling cadence follows the section's visibility (1s on
// screen, 2s off) -- handled inside the Resources singleton.
import QtQuick

Column {
    id: root

    // The panel opens the processes SubPage when this fires.
    signal processesRequested()

    width: parent.width
    spacing: Tokens.space.xs

    onVisibleChanged: Resources.detailVisible = visible
    Component.onCompleted: Resources.detailVisible = Resources.detailVisible || visible

    component MetricRow: Row {
        id: metricRow

        required property string label
        required property var history
        required property string value
        required property bool alarming

        width: parent.width
        height: 40
        spacing: Tokens.space.s

        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: 96
            text: metricRow.label
            color: Theme.fg0
            font.family: "Adwaita Sans"
            font.pixelSize: 13
        }

        Sparkline {
            anchors.verticalCenter: parent.verticalCenter
            width: 140
            height: 20
            samples: metricRow.history
            highlighted: metricRow.alarming
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - x
            horizontalAlignment: Text.AlignRight
            text: metricRow.value
            color: metricRow.alarming ? Theme.red : Theme.fg0
            font.family: "Adwaita Sans"
            font.pixelSize: 13
            font.features: ({ "tnum": 1 })

            Behavior on color {
                ColorAnimation { duration: Motion.fast }
            }
        }
    }

    MetricRow {
        label: "CPU"
        history: Resources.cpuHistory
        value: Math.round(Resources.cpu * 100) + "%"
        alarming: Resources.alert === "cpu" || Resources.alertCritical
    }

    MetricRow {
        label: "Memory"
        history: Resources.memHistory
        value: Resources.memUsedGiB.toFixed(1) + " / " + Resources.memTotalGiB.toFixed(1) + " GB"
        alarming: Resources.alert === "mem" || Resources.alertCritical
    }

    MetricRow {
        label: "Temperature"
        history: Resources.tempHistory
        value: isNaN(Resources.tempC) ? "—" : Math.round(Resources.tempC) + " °C"
        alarming: Resources.alert === "temp" || Resources.alertCritical
    }

    // The secondary line: load and swap.
    Text {
        width: parent.width
        text: "Load " + Resources.load1.toFixed(2)
            + (Resources.swapTotalGiB > 0
                ? "   Swap (zram) " + Resources.swapUsedGiB.toFixed(1) + " / "
                  + Resources.swapTotalGiB.toFixed(1) + " GB"
                : "")
        color: Theme.fg1
        font.family: "Adwaita Sans"
        font.pixelSize: 12
    }

    Pressable {
        width: processesText.implicitWidth + Tokens.space.s * 2
        height: 26

        onClicked: root.processesRequested()

        Text {
            id: processesText
            anchors.centerIn: parent
            text: "Processes ›"
            color: parent.hovered ? Theme.gold : Theme.fg1
            font.family: "Adwaita Sans"
            font.pixelSize: 12
        }
    }
}
