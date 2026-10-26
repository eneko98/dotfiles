// The battery glyph + percentage: display only (the System panel's header
// owns the detail). Charging lights the glyph; <=20% brightens; <=10% while
// discharging is the alarm red. The tooltip carries the time.
import Quickshell
import Quickshell.Services.UPower
import QtQuick

Item {
    id: root

    signal activated(string section)

    readonly property var battery: UPower.displayDevice
    readonly property bool ready: battery ? battery.ready : false
    readonly property real fraction: battery ? battery.percentage : 0
    readonly property int state: battery ? battery.state : UPowerDeviceState.Unknown
    readonly property bool charging: state === UPowerDeviceState.Charging
        || state === UPowerDeviceState.PendingCharge
    readonly property bool critical: !charging && fraction <= 0.10

    width: batteryText.implicitWidth > 0 ? glyph.width + 4 + batteryText.implicitWidth : 20
    height: 30

    function duration(seconds) {
        if (!seconds || seconds <= 0)
            return "";
        const total = Math.round(seconds / 60);
        const hours = Math.floor(total / 60);
        const minutes = total % 60;
        return hours > 0 ? hours + "h " + minutes + "m" : minutes + "m";
    }

    readonly property string timeText: {
        if (!battery || !ready)
            return "";
        if (charging && battery.timeToFull > 0)
            return duration(battery.timeToFull) + " to full";
        if (!charging && battery.timeToEmpty > 0)
            return duration(battery.timeToEmpty) + " left";
        return "";
    }

    Pressable {
        id: press
        anchors.fill: parent

        onClicked: root.activated("battery")

        Row {
            anchors.centerIn: parent
            spacing: 4

            Glyph {
                anchors.verticalCenter: parent.verticalCenter
                glyph: root.fraction >= 0.9 ? "󰁹"
                    : root.fraction >= 0.6 ? "󰂂"
                    : root.fraction >= 0.35 ? "󰂀"
                    : root.fraction >= 0.15 ? "󰁿"
                    : "󰁺"
                tone: root.critical ? "alarm"
                    : root.charging ? "active"
                    : root.fraction <= 0.20 ? "bright" : "normal"
                size: 15
            }

            Text {
                id: batteryText
                anchors.verticalCenter: parent.verticalCenter
                visible: root.ready
                text: Math.round(root.fraction * 100) + "%"
                color: root.critical ? Theme.red
                    : root.fraction <= 0.20 ? Theme.fg0 : Theme.fg1
                font.family: "Adwaita Sans"
                font.pixelSize: 12
                font.features: ({ "tnum": 1 })
            }
        }
    }

    Tooltip {
        hovered: press.hovered
        label: root.timeText !== "" ? root.timeText
            : (root.charging ? "Charging" : "On battery")
        below: false
        anchors.bottom: parent.top
        anchors.bottomMargin: Tokens.space.xs
        anchors.horizontalCenter: parent.horizontalCenter
    }
}
