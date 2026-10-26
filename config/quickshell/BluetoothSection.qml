// Bluetooth: the tile switches the adapter; the chevron opens the device
// list. Bluetooth.defaultAdapter.devices holds paired devices *and* whatever
// discovery has found, so discovery runs while the detail is open. A row's
// click does the obvious thing for its state: disconnect when connected,
// connect when paired, pair when new.
//
// Pairing needs a BlueZ agent, so bt-agent (NoInputNoOutput, auto-confirms
// Just Works) runs only while the detail is open -- nobody can pair from a
// distance the rest of the time. bt-agent ignores SIGTERM: the stop is
// SIGKILL, and the start/stop is imperative (a `running:` binding breaks
// when Process writes the property back).
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import QtQuick

Column {
    id: root

    property bool expanded: false
    // The System panel composes the tile itself; sections used standalone
    // keep their tile.
    property bool showTile: true

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool on: adapter ? adapter.enabled : false

    readonly property var connectedDevice: {
        if (!adapter)
            return null;
        const devices = adapter.devices.values;
        for (let i = 0; i < devices.length; ++i)
            if (devices[i].connected)
                return devices[i];
        return null;
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

    function updateAgent() {
        const wanted = root.expanded && root.adapter !== null && root.adapter.enabled;

        if (wanted) {
            if (!agent.running)
                agent.running = true;
        } else if (agent.running) {
            agent.signal(9);
        }
    }

    onExpandedChanged: {
        root.updateAgent();

        if (root.adapter)
            root.adapter.discovering = root.expanded && root.adapter.enabled;
    }

    Connections {
        target: root.adapter

        function onEnabledChanged() {
            root.updateAgent();

            if (root.adapter && root.expanded)
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

    // --- The tile ---------------------------------------------------------
    ToggleTile {
        width: parent.width
        visible: root.showTile
        checked: root.on
        glyph: "\uf293"
        title: "Bluetooth"
        subtitle: root.on ? (root.connectedDevice ? root.connectedDevice.name : "On") : "Off"

        onToggled: {
            if (root.adapter)
                root.adapter.enabled = !root.adapter.enabled;
        }
        onExpandRequested: root.expanded = !root.expanded
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

            Text {
                visible: !root.on
                text: "Bluetooth is off"
                color: Theme.fg2
                font.family: "Adwaita Sans"
                font.pixelSize: 12
            }

            Flickable {
                id: list

                visible: root.on
                width: parent.width
                height: Math.min(contentHeight, 288)
                contentHeight: deviceColumn.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                // Wheel + two fingers, the same wheel-only MouseArea as the
                // network list's.
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton

                    onWheel: function (w) {
                        const dy = w.pixelDelta.y !== 0
                            ? w.pixelDelta.y : (w.angleDelta.y / 120) * 40;
                        list.contentY = Math.max(0,
                            Math.min(list.contentHeight - list.height,
                                     list.contentY - dy));
                    }
                }

                Column {
                    id: deviceColumn
                    width: parent.width
                    spacing: 2

                    Repeater {
                        model: root.devices

                        delegate: Pressable {
                            id: row

                            required property var modelData

                            width: parent.width
                            height: 36

                            onClicked: root.activate(row.modelData)

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: Tokens.space.s
                                anchors.right: rowState.left
                                anchors.rightMargin: Tokens.space.s
                                anchors.verticalCenter: parent.verticalCenter
                                text: row.modelData.name
                                color: row.modelData.connected ? Theme.gold : Theme.fg0
                                font.family: "Adwaita Sans"
                                font.pixelSize: 13
                                elide: Text.ElideRight
                            }

                            Text {
                                id: rowState

                                anchors.right: parent.right
                                anchors.rightMargin: Tokens.space.s
                                anchors.verticalCenter: parent.verticalCenter
                                text: row.modelData.connected
                                    ? (row.modelData.batteryAvailable
                                        ? Math.round(row.modelData.battery * 100) + "%"
                                        : "✓")
                                    : row.modelData.pairing ? "pairing…"
                                    : row.modelData.paired ? "paired"
                                    : ""
                                color: row.modelData.connected ? Theme.gold
                                    : row.modelData.pairing ? Theme.teal
                                    : Theme.fg1
                                font.family: "Adwaita Sans"
                                font.pixelSize: 11
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
                font.pixelSize: 12
            }
        }
    }

    Process {
        id: agent
        command: ["bt-agent", "-c", "NoInputNoOutput"]
    }
}
