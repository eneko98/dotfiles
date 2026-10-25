// The bluetooth popup: the adapter switch and the devices it knows about.
//
// Bluetooth.defaultAdapter.devices holds paired devices *and* whatever discovery
// has found, so discovery is enabled only while the popup is open. A row's click
// does the obvious thing for its state: disconnect when connected, connect when
// paired, pair when it is a new device (and the pairing completion connects it).
//
// Battery is only valid when the device reports it (`batteryAvailable`) and is
// 0.0 to 1.0, the same fraction trap as UPower.

import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import QtQuick

Popup {
    id: root

    panelWidth: 300

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool on: adapter ? adapter.enabled : false

    // Pairing needs a BlueZ agent and this machine has none, so one is started
    // only while the popup is open: bt-agent (bluez-tools) with the
    // NoInputNoOutput capability auto-confirms a Just Works pairing, and when
    // the popup closes the agent goes away with SIGTERM. Nobody can pair while
    // the popup is closed, which is also the safer default.
    //
    // The start/stop is imperative, not a `running:` binding: Process writes its
    // own `running` when it starts and exits, which breaks the binding and left
    // the agent alive after the popup closed (measured with a timer).
    Process {
        id: agent
        command: ["bt-agent", "-c", "NoInputNoOutput"]
    }

    function updateAgent() {
        const wanted = root.visible && root.adapter !== null && root.adapter.enabled;

        if (wanted) {
            if (!agent.running)
                agent.running = true;
        } else if (agent.running) {
            // bt-agent ignores SIGTERM (measured: `kill` left it alive), so
            // `running = false` would not stop it. SIGKILL it instead; the bus
            // connection dies with the process and BlueZ drops the agent.
            agent.signal(9);
        }
    }

    // Connected first, then paired, then by name.
    readonly property var devices: {
        const a = root.adapter;
        const list = a ? a.devices.values.slice() : [];

        list.sort(function (x, y) {
            return (y.connected ? 1 : 0) - (x.connected ? 1 : 0)
                || (y.paired ? 1 : 0) - (x.paired ? 1 : 0)
                || x.name.localeCompare(y.name);
        });

        return list;
    }

    onVisibleChanged: {
        root.updateAgent();

        if (root.adapter)
            root.adapter.discovering = root.visible && root.adapter.enabled;
    }

    Connections {
        target: root.adapter

        function onEnabledChanged() {
            root.updateAgent();

            if (root.adapter && root.visible)
                root.adapter.discovering = root.adapter.enabled;
        }
    }

    function activate(device) {
        if (device.connected)
            device.disconnect();
        else if (device.paired)
            device.connect();
        else
            device.pair();
    }

    // --- Header: title and the adapter switch ------------------------------
    Item {
        width: parent.width
        height: 18

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "Bluetooth"
            color: Theme.fg1
            font.family: "Adwaita Sans"
            font.pixelSize: 11
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.on ? "On" : "Off"
            color: root.on ? Theme.gold : Theme.fg2
            font.family: "Adwaita Sans"
            font.pixelSize: 11

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: if (root.adapter)
                    root.adapter.enabled = !root.adapter.enabled
            }
        }
    }

    // --- Adapter off -------------------------------------------------------
    Text {
        visible: !root.on
        text: "Bluetooth is off"
        color: Theme.fg2
        font.family: "Adwaita Sans"
        font.pixelSize: 11
    }

    // --- The device list ---------------------------------------------------
    Flickable {
        id: list

        visible: root.on
        width: parent.width
        height: Math.min(contentHeight, 320)
        contentHeight: deviceColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: deviceColumn
            width: list.width
            spacing: 2

            Repeater {
                model: root.devices

                delegate: Rectangle {
                    id: row

                    required property var modelData

                    width: deviceColumn.width
                    height: 26
                    radius: 4
                    color: hover.containsMouse && !row.modelData.connected ? Theme.bg2 : "transparent"

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 6
                        anchors.right: state.left
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.modelData.name
                        color: row.modelData.connected ? Theme.gold : Theme.fg0
                        font.family: "Adwaita Sans"
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }

                    Text {
                        id: state

                        anchors.right: parent.right
                        anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.modelData.connected
                                ? (row.modelData.batteryAvailable
                                    ? Math.round(row.modelData.battery * 100) + "%"
                                    : "✓")
                            : row.modelData.pairing ? "…"
                            : row.modelData.paired ? "paired"
                            : ""
                        color: row.modelData.connected ? Theme.gold
                            : row.modelData.pairing ? Theme.teal
                            : Theme.fg2
                        font.family: "Adwaita Sans"
                        font.pixelSize: 11
                    }

                    MouseArea {
                        id: hover

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.activate(row.modelData)
                    }
                }
            }
        }
    }

    Text {
        visible: root.on && root.devices.length === 0
        text: "Searching…"
        color: Theme.fg2
        font.family: "Adwaita Sans"
        font.pixelSize: 11
    }
}
