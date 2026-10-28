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
        else {
            device.pair();
            root.requestConnectAfterPair(device);
        }
    }

    // --- Pair then connect ------------------------------------------------
    // The delegate's Connections died when the model recreated the device on
    // `paired`, so the connect after pairing is tracked by ADDRESS on the
    // section, not by object. A timer resolves it while there are pending
    // addresses and gives up after 30 s.
    property var pendingConnect: ({})
    property double pendingSince: 0

    function requestConnectAfterPair(device) {
        const next = Object.assign({}, root.pendingConnect);
        next[device.address] = true;
        root.pendingConnect = next;
        if (root.pendingSince === 0)
            root.pendingSince = Date.now();
    }

    function resolvePending() {
        if (Date.now() - root.pendingSince > 30000) {
            root.pendingConnect = ({});
            root.pendingSince = 0;
            return;
        }
        const devices = root.adapter ? root.adapter.devices.values : [];
        let next = Object.assign({}, root.pendingConnect);
        let changed = false;
        for (let i = 0; i < devices.length; ++i) {
            const d = devices[i];
            if (next[d.address] && d.paired) {
                delete next[d.address];
                changed = true;
                d.connect();
            }
        }
        if (changed) {
            root.pendingConnect = next;
            if (Object.keys(next).length === 0)
                root.pendingSince = 0;
        }
    }

    Timer {
        interval: 500
        repeat: true
        running: Object.keys(root.pendingConnect).length > 0
        onTriggered: root.resolvePending()
    }

    // --- Connection notifications -----------------------------------------
    // A one-second diff of the connected set is simpler and sturdier than
    // connecting to signals on objects that the model recreates. The first
    // tick only records the baseline, so startup does not spam.
    property var lastConnected: ({})
    property bool notificationsArmed: false

    function notify(title, body) {
        Quickshell.execDetached(["notify-send", "-a", "Bluetooth",
            "-i", "bluetooth", title, body]);
    }

    function checkConnections() {
        const devices = root.adapter ? root.adapter.devices.values : [];
        let now = {};
        for (let i = 0; i < devices.length; ++i) {
            const d = devices[i];
            if (d.connected)
                now[d.address] = d.name;
        }
        if (!root.notificationsArmed) {
            root.notificationsArmed = true;
            root.lastConnected = now;
            return;
        }
        for (const addr in now) {
            if (!root.lastConnected[addr])
                root.notify("Connected", now[addr]);
        }
        for (const addr in root.lastConnected) {
            if (!now[addr])
                root.notify("Disconnected", root.lastConnected[addr]);
        }
        root.lastConnected = now;
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.on
        onTriggered: root.checkConnections()
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
                // On TOP of the rows (declared last): wheel dispatch goes
                // to the topmost item under the cursor. Clicks pass through
                // (no buttons); the wheel scrolls from cursor or fingers.
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
