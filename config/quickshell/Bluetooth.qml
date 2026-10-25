// The bluetooth module: a glyph that dims when the adapter is off, the name of
// the connected device when there is one, and a click that powers the adapter
// on or off.
//
// Bluetooth.defaultAdapter is the adapter (usually one). Its `devices` model
// holds the devices connected to it, and the one with connected === true is the
// one to show. `enabled` is writable, which is what the TapHandler toggles.

import Quickshell
import Quickshell.Bluetooth
import QtQuick

Row {
    id: root

    spacing: 6

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

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: ""
        color: root.on ? Theme.fg1 : Theme.fg2
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 14
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        visible: root.device !== null
        text: root.device ? root.device.name : ""
        color: Theme.fg1
        font.family: "Adwaita Sans"
        font.pixelSize: 12
    }

    TapHandler {
        onTapped: {
            if (root.adapter)
                root.adapter.enabled = !root.adapter.enabled;
        }
    }
}
