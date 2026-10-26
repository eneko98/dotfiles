// The wifi glyph: display and interactions only. The glyph follows the
// signal strength; without the radio the module hides; without a network
// the tooltip says so. Click opens System's network section.
import Quickshell
import Quickshell.Networking
import QtQuick

Item {
    id: root

    signal activated(string section)

    readonly property var device: {
        const devices = Networking.devices.values;
        for (let i = 0; i < devices.length; ++i)
            if (devices[i].type === DeviceType.Wifi)
                return devices[i];
        return null;
    }

    readonly property var network: {
        if (!device)
            return null;
        const networks = device.networks.values;
        for (let i = 0; i < networks.length; ++i)
            if (networks[i].connected)
                return networks[i];
        return null;
    }

    // Without the radio: hidden (brief 14.3).
    visible: Networking.wifiEnabled

    width: 20
    height: 30

    function signalGlyph(strength, connected) {
        if (!connected)
            return "󰤭";
        return strength >= 80 ? "󰤨"
            : strength >= 60 ? "󰤥"
            : strength >= 40 ? "󰤢"
            : strength >= 20 ? "󰤟"
            : "󰤟";  // connected with very low signal: one bar, not the off glyph
    }

    Pressable {
        id: press
        anchors.fill: parent

        onClicked: root.activated("network")

        Glyph {
            anchors.centerIn: parent
            glyph: root.signalGlyph(root.network ? root.network.signalStrength : 0, root.network !== null)
            tone: root.network ? "normal" : "disabled"
            size: 15
        }
    }

    Tooltip {
        hovered: press.hovered
        label: root.network
            ? root.network.name + ", " + root.network.signalStrength + "%"
            : "Disconnected"
        below: false
        anchors.bottom: parent.top
        anchors.bottomMargin: Tokens.space.xs
        anchors.horizontalCenter: parent.horizontalCenter
    }
}
