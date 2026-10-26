// The battery module: a battery glyph by level and the percentage. Clicking it
// opens our own popup (BatteryPopup.qml) with the state, time, power and health.
//
// UPower.displayDevice is the aggregate device desktop environments show. It is
// never null, but may not be initialised yet, so `ready` guards the bindings.
// The state decides the colour: gold while charging (energy, the accent), red at
// or below 15% and not charging (the palette's alarm), fg1 otherwise.

import Quickshell
import Quickshell.Services.UPower
import QtQuick

Row {
    id: root

    // The bar routes this to the System panel; the module keeps its own
    // popup only for the control centre's hand-offs (both are retiring).
    signal activated()

    spacing: 6

    visible: root.ready

    readonly property var battery: UPower.displayDevice
    readonly property bool ready: battery ? battery.ready : false
    // 0.0 to 1.0, not 0 to 100: the docs define it as energy / energyCapacity.
    readonly property real fraction: battery ? battery.percentage : 0
    readonly property int state: battery ? battery.state : UPowerDeviceState.Unknown
    readonly property bool charging: state === UPowerDeviceState.Charging || state === UPowerDeviceState.PendingCharge
    readonly property bool low: !charging && fraction <= 0.15

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: {
            if (root.fraction >= 0.9)
                return "";
            if (root.fraction >= 0.6)
                return "";
            if (root.fraction >= 0.35)
                return "";
            if (root.fraction >= 0.15)
                return "";
            return "";
        }
        color: root.charging ? Theme.gold : (root.low ? Theme.red : Theme.fg1)
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 14
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: Math.round(root.fraction * 100) + "%"
        color: root.low ? Theme.red : Theme.fg1
        font.family: "Adwaita Sans"
        font.pixelSize: 12
    }

    BatteryPopup {
        id: popup
    }

    // Also called by the control centre: the popup opens under the module no
    // matter where the request came from.
    function openPopup() {
        const p = root.mapToItem(null, 0, 0);
        popup.rightMargin = root.Window.width - (p.x + root.width);
        popup.visible = true;
    }

    TapHandler {
        onTapped: root.activated()
    }
}
