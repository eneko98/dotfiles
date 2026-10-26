// The bluetooth glyph: hidden while the radio is off (brief 14.3); the
// connected device's name in the tooltip. Click opens System's bluetooth
// section.
import Quickshell
import Quickshell.Bluetooth
import QtQuick

Item {
    id: root

    signal activated(string section)

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool on: adapter ? adapter.enabled : false

    readonly property var device: {
        if (!adapter)
            return null;
        const devices = adapter.devices.values;
        for (let i = 0; i < devices.length; ++i)
            if (devices[i].connected)
                return devices[i];
        return null;
    }

    // Off: hidden.
    visible: root.on

    width: 20
    height: 30

    Pressable {
        id: press
        anchors.fill: parent

        onClicked: root.activated("bluetooth")

        Glyph {
            anchors.centerIn: parent
            glyph: "\uf293"
            // Connected: bright fg0; on without a connection: fg1.
            tone: root.device ? "bright" : "normal"
            size: 15
        }
    }

    Tooltip {
        hovered: press.hovered
        label: root.device ? root.device.name : "On"
        below: false
        anchors.bottom: parent.top
        anchors.bottomMargin: Tokens.space.xs
        anchors.horizontalCenter: parent.horizontalCenter
    }
}
