// The battery popup: the charge as a number and a bar, plus the numbers the
// bar's percentage hides — state, time left or to full, power draw and health.
//
// Everything comes from UPower.displayDevice. The traps are the same as in the
// Battery module: percentage is 0.0 to 1.0, timeToEmpty is 0 while charging and
// timeToFull is 0 while discharging, and changeRate is positive when charging.
// healthPercentage is a percentage (0-100), not a fraction.

import Quickshell
import Quickshell.Services.UPower
import QtQuick

Popup {
    id: root

    panelWidth: 260

    readonly property var battery: UPower.displayDevice
    readonly property bool ready: battery ? battery.ready : false
    readonly property real fraction: battery ? battery.percentage : 0
    readonly property int state: battery ? battery.state : UPowerDeviceState.Unknown
    readonly property bool charging: state === UPowerDeviceState.Charging
        || state === UPowerDeviceState.PendingCharge
    readonly property bool low: !charging && fraction <= 0.15

    function duration(seconds) {
        if (!seconds || seconds <= 0)
            return "";

        const total = Math.round(seconds / 60);
        const hours = Math.floor(total / 60);
        const minutes = total % 60;

        return hours > 0 ? hours + "h " + minutes + "m" : minutes + "m";
    }

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

    Text {
        text: "Battery"
        color: Theme.fg1
        font.family: "Adwaita Sans"
        font.pixelSize: 11
    }

    Row {
        width: parent.width
        spacing: 8

        Text {
            text: Math.round(root.fraction * 100) + "%"
            color: root.low ? Theme.red : Theme.fg0
            font.family: "Adwaita Sans"
            font.pixelSize: 20
            font.bold: true
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.stateText
            color: Theme.fg1
            font.family: "Adwaita Sans"
            font.pixelSize: 11
        }
    }

    // The charge bar: the same gold as the volume fill, red when it is low.
    Item {
        width: parent.width
        height: 6

        Rectangle {
            anchors.fill: parent
            radius: 3
            color: Theme.bg2
        }

        Rectangle {
            width: parent.width * root.fraction
            height: parent.height
            radius: 3
            color: root.low ? Theme.red : Theme.gold
        }
    }

    Item {
        width: parent.width
        height: 16

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "Time"
            color: Theme.fg2
            font.family: "Adwaita Sans"
            font.pixelSize: 11
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.timeText
            color: Theme.fg1
            font.family: "Adwaita Sans"
            font.pixelSize: 11
        }
    }

    Item {
        width: parent.width
        height: 16

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "Power"
            color: Theme.fg2
            font.family: "Adwaita Sans"
            font.pixelSize: 11
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.powerText
            color: Theme.fg1
            font.family: "Adwaita Sans"
            font.pixelSize: 11
        }
    }

    Item {
        width: parent.width
        height: 16

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "Health"
            color: Theme.fg2
            font.family: "Adwaita Sans"
            font.pixelSize: 11
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.healthText
            color: Theme.fg1
            font.family: "Adwaita Sans"
            font.pixelSize: 11
        }
    }
}
