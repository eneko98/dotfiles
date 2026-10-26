// The wifi glyph: display and interactions only. The glyph follows the
// signal strength; without the radio the module hides; without a network
// the tooltip says so. Click opens System's network section.
//
// Quickshell's connected WifiNetwork entry often reports signalStrength 0 even
// though NetworkManager knows the real value, so we probe nmcli directly on a
// timer and use that when it answers.
import Quickshell
import Quickshell.Io
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

    // Signal strength from nmcli (the source of truth); -1 means "not known yet
    // or probe failed", fall back to Quickshell's value.
    property int realSignal: -1

    readonly property int signalStrength: {
        if (root.realSignal >= 0)
            return root.realSignal;
        return root.network ? root.network.signalStrength : 0;
    }

    Process {
        id: signalProbe

        command: ["nmcli", "-t", "-f", "ACTIVE,SIGNAL", "dev", "wifi"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n");
                for (let i = 0; i < lines.length; ++i) {
                    const parts = lines[i].split(":");
                    if (parts[0] === "yes" && parts[1] !== "") {
                        root.realSignal = parseInt(parts[1], 10);
                        return;
                    }
                }
                root.realSignal = -1;
            }
        }
    }

    Timer {
        interval: 5000
        repeat: true
        running: root.network !== null
        triggeredOnStart: true

        onTriggered: {
            signalProbe.running = false;
            signalProbe.running = true;
        }
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
            : "󰤟";
    }

    Pressable {
        id: press

        anchors.fill: parent

        onClicked: root.activated("network")

        Glyph {
            anchors.centerIn: parent
            glyph: root.signalGlyph(root.signalStrength, root.network !== null)
            tone: root.network ? "normal" : "disabled"
            size: 15
        }
    }

    Tooltip {
        hovered: press.hovered
        label: root.network
            ? root.network.name + ", " + root.signalStrength + "%"
            : "Disconnected"
        below: false
        anchors.bottom: parent.top
        anchors.bottomMargin: Tokens.space.xs
        anchors.horizontalCenter: parent.horizontalCenter
    }
}
