// Battery: the header (glyph, the percentage in 15 SemiBold, state and time
// in fg1) is clickable and opens the detail -- health, energy and power
// draw. Everything comes from UPower.displayDevice; the traps: percentage
// is 0..1, timeToEmpty is 0 while charging (and timeToFull while
// discharging), changeRate is positive when charging, healthPercentage is
// 0-100. Red appears only at <= 10% while discharging; <= 20% brightens the
// number to fg0.
import Quickshell.Services.UPower
import QtQuick

Column {
    id: root

    property bool expanded: false

    width: parent.width
    spacing: Tokens.space.s

    readonly property var battery: UPower.displayDevice
    readonly property bool ready: battery ? battery.ready : false
    readonly property real fraction: battery ? battery.percentage : 0
    readonly property int state: battery ? battery.state : UPowerDeviceState.Unknown
    readonly property bool charging: state === UPowerDeviceState.Charging
        || state === UPowerDeviceState.PendingCharge
    readonly property bool critical: !charging && fraction <= 0.10

    function duration(seconds) {
        if (!seconds || seconds <= 0)
            return "";

        const total = Math.round(seconds / 60);
        const hours = Math.floor(total / 60);
        const minutes = total % 60;

        return hours > 0 ? hours + "h " + minutes + "m" : minutes + "m";
    }

    readonly property string glyphChar: fraction >= 0.9 ? "󰁹"
        : fraction >= 0.6 ? "󰂂"
        : fraction >= 0.35 ? "󰂀"
        : fraction >= 0.15 ? "󰁿"
        : "󰁺"

    readonly property string stateText: {
        switch (state) {
        case UPowerDeviceState.Charging: return "Charging";
        case UPowerDeviceState.Discharging: return "Discharging";
        case UPowerDeviceState.FullyCharged: return "Fully charged";
        case UPowerDeviceState.PendingCharge: return "Pending charge";
        case UPowerDeviceState.PendingDischarge: return "Pending discharge";
        case UPowerDeviceState.Empty: return "Empty";
        default: return "Unknown";
        }
    }

    readonly property string timeText: {
        if (!battery || !ready)
            return "—";
        if (charging && battery.timeToFull > 0)
            return duration(battery.timeToFull) + " to full";
        if (!charging && battery.timeToEmpty > 0)
            return duration(battery.timeToEmpty) + " left";
        return "—";
    }

    readonly property string powerText: {
        if (!battery || !ready || Math.abs(battery.changeRate) < 0.05)
            return "—";
        return Math.abs(battery.changeRate).toFixed(1) + " W "
            + (battery.changeRate > 0 ? "in" : "out");
    }

    readonly property string healthText: {
        if (!battery || !ready || !battery.healthSupported)
            return "—";
        return Math.round(battery.healthPercentage) + "% of design";
    }

    // --- The header -------------------------------------------------------
    Pressable {
        width: parent.width
        height: 40

        onClicked: root.expanded = !root.expanded

        Glyph {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            glyph: root.glyphChar
            tone: root.charging ? "active" : root.critical ? "alarm" : "normal"
            size: 16
        }

        Column {
            anchors.left: parent.left
            anchors.leftMargin: Tokens.space.l
            anchors.right: parent.right
            anchors.rightMargin: Tokens.space.l
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Text {
                text: Math.round(root.fraction * 100) + "%"
                color: root.critical ? Theme.red : Theme.fg0
                font.family: "Adwaita Sans"
                font.pixelSize: 15
                font.weight: Font.DemiBold
                font.features: ({ "tnum": 1 })

                Behavior on color {
                    ColorAnimation { duration: Motion.fast }
                }
            }

            Text {
                text: root.stateText + (root.timeText !== "—" ? ", " + root.timeText : "")
                color: Theme.fg1
                font.family: "Adwaita Sans"
                font.pixelSize: 11
            }
        }
    }

    // --- The detail -------------------------------------------------------
    Item {
        width: parent.width
        height: root.expanded ? detailCol.implicitHeight : 0
        clip: true

        Behavior on height {
            NumberAnimation {
                duration: Motion.medium
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.standard
            }
        }

        Column {
            id: detailCol
            width: parent.width
            spacing: Tokens.space.xs

            DetailRow { label: "Health"; value: root.healthText }
            DetailRow {
                label: "Capacity"
                value: root.battery && root.ready
                    ? (root.battery.energy / 1000000).toFixed(1) + " / "
                      + (root.battery.energyCapacity / 1000000).toFixed(1) + " Wh"
                    : "—"
            }
            DetailRow { label: "Power"; value: root.powerText }
            DetailRow {
                label: "Model"
                value: root.battery && root.battery.model !== "" ? root.battery.model : "—"
            }
        }
    }

    component DetailRow: Row {
        property string label: ""
        property string value: ""

        width: parent.width
        height: 24
        spacing: Tokens.space.s

        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: 72
            text: parent.label
            color: Theme.fg1
            font.family: "Adwaita Sans"
            font.pixelSize: 12
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - x
            text: parent.value
            color: Theme.fg0
            font.family: "Adwaita Sans"
            font.pixelSize: 12
            elide: Text.ElideRight
        }
    }
}
