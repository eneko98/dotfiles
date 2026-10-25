// The wifi module: a wifi glyph and the SSID of the connected network.
// Clicking it opens our own popup (WifiPopup.qml): radio switch, the visible
// networks and a password field for one we have never joined.
//
// Networking.devices is an ObjectModel of every network device; the wifi one
// is found by type. Its networks model lists the visible/connected networks,
// and the connected one gives us the name (the SSID) and the signal strength.
// Everything is a binding, so the module follows NetworkManager on its own.

import Quickshell
import Quickshell.Networking
import QtQuick

Row {
    id: root

    spacing: 6

    // A plain loop rather than Array.find: `values` is a QML list, and this is
    // the form that definitely works on it.
    function wifiDevice() {
        const devices = Networking.devices.values;
        for (let i = 0; i < devices.length; ++i)
            if (devices[i].type === DeviceType.Wifi)
                return devices[i];
        return null;
    }

    function connectedNetwork(device) {
        if (!device)
            return null;
        const networks = device.networks.values;
        for (let i = 0; i < networks.length; ++i)
            if (networks[i].connected)
                return networks[i];
        return null;
    }

    readonly property var device: wifiDevice()
    readonly property var network: connectedNetwork(device)
    readonly property bool connected: device ? device.connected : false
    readonly property string ssid: network ? network.name : ""

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: ""
        color: root.connected ? Theme.fg1 : Theme.fg2
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 14
    }

    // The SSID only when there is one; otherwise just the dimmed glyph.
    Text {
        anchors.verticalCenter: parent.verticalCenter
        visible: root.connected
        text: root.ssid
        color: Theme.fg1
        font.family: "Adwaita Sans"
        font.pixelSize: 12
    }

    WifiPopup {
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
        onTapped: root.openPopup()
    }
}
