// Wi-Fi: the tile switches the radio; the chevron opens the detail with the
// current network on top, the visible networks sorted by signal (36 px rows:
// signal glyph, SSID, lock if secured, Saved when known) and a password
// entry for a network we have never joined.
//
// WifiDevice.networks only holds what the scanner has found, so the scanner
// runs while the detail is open and stops when it closes. Connection is
// NetworkManager's: connect() for a known network, connectWithPsk() for a
// new secured one; a failure comes back as connectionFailed on the network
// and is shown on the row with a red dot.
import Quickshell
import Quickshell.Networking
import QtQuick

Column {
    id: root

    property bool expanded: false
    // The network waiting for a password, and the one a failure can come from.
    property var pending: null
    property var connecting: null
    property string error: ""

    readonly property var device: {
        const devices = Networking.devices.values;
        for (let i = 0; i < devices.length; ++i)
            if (devices[i].type === DeviceType.Wifi)
                return devices[i];
        return null;
    }

    readonly property var connectedNet: {
        if (!device)
            return null;
        const networks = device.networks.values;
        for (let i = 0; i < networks.length; ++i)
            if (networks[i].connected)
                return networks[i];
        return null;
    }

    // Connected first, then strongest; through `.values`, the reactive view.
    readonly property var networks: {
        const d = root.device;
        const list = d ? d.networks.values.slice() : [];
        list.sort(function (a, b) {
            return (b.connected ? 1 : 0) - (a.connected ? 1 : 0)
                || b.signalStrength - a.signalStrength;
        });
        return list;
    }

    function needsPsk(network) {
        return network.security === WifiSecurityType.WpaPsk
            || network.security === WifiSecurityType.Wpa2Psk
            || network.security === WifiSecurityType.Sae;
    }

    function activate(network) {
        root.error = "";

        if (network.connected)
            return;

        if (network.known || !root.needsPsk(network)) {
            root.connecting = network;
            network.connect();
            return;
        }

        root.pending = network;
        Qt.callLater(function () {
            password.forceActiveFocus();
        });
    }

    function submit() {
        if (root.pending === null || password.text.length === 0)
            return;

        root.connecting = root.pending;
        root.pending.connectWithPsk(password.text);
        password.text = "";
        root.pending = null;
    }

    function signalGlyph(strength) {
        return strength >= 80 ? "󰤨"
            : strength >= 60 ? "󰤥"
            : strength >= 40 ? "󰤢"
            : strength >= 20 ? "󰤟"
            : "󰤭";
    }

    onExpandedChanged: {
        if (root.device)
            root.device.scannerEnabled = root.expanded;

        if (!root.expanded) {
            root.pending = null;
            root.connecting = null;
            root.error = "";
        }
    }

    Connections {
        target: root.connecting

        function onConnectionFailed() {
            root.error = "Connection failed";
        }
    }

    // --- The tile ---------------------------------------------------------
    ToggleTile {
        width: parent.width
        checked: Networking.wifiEnabled
        glyph: "󰖩"
        title: "Wi-Fi"
        subtitle: Networking.wifiEnabled
            ? (root.connectedNet ? root.connectedNet.name : "Disconnected")
            : "Off"
        busy: root.connecting !== null

        onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
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

            // Radio off: nothing else to show.
            Text {
                visible: !Networking.wifiEnabled
                text: "Wi-Fi is off"
                color: Theme.fg2
                font.family: "Adwaita Sans"
                font.pixelSize: 12
            }

            // The current network, above the list.
            Text {
                visible: Networking.wifiEnabled && root.connectedNet !== null
                text: root.connectedNet ? root.connectedNet.name + " · Connected" : ""
                color: Theme.fg0
                font.family: "Adwaita Sans"
                font.pixelSize: 13
            }

            Flickable {
                visible: Networking.wifiEnabled && root.pending === null
                width: parent.width
                height: Math.min(contentHeight, 288)
                contentHeight: networkColumn.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: networkColumn
                    width: parent.width
                    spacing: 2

                    Repeater {
                        model: root.networks

                        delegate: Pressable {
                            id: row

                            required property var modelData

                            width: parent.width
                            height: 36

                            onClicked: root.activate(row.modelData)

                            Glyph {
                                anchors.left: parent.left
                                anchors.leftMargin: Tokens.space.s
                                anchors.verticalCenter: parent.verticalCenter
                                glyph: root.signalGlyph(row.modelData.signalStrength)
                                tone: row.modelData.connected ? "active" : "normal"
                                size: 14
                            }

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: Tokens.space.l
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
                                text: row.modelData.known && !row.modelData.connected ? "Saved" : ""
                                color: Theme.fg1
                                font.family: "Adwaita Sans"
                                font.pixelSize: 11
                            }

                            Glyph {
                                anchors.right: parent.right
                                anchors.rightMargin: rowState.text !== "" ? 44 : Tokens.space.s
                                anchors.verticalCenter: parent.verticalCenter
                                glyph: root.needsPsk(row.modelData) ? "\uf023" : ""
                                tone: "disabled"
                                size: 12
                            }
                        }
                    }
                }
            }

            Text {
                visible: Networking.wifiEnabled && root.pending === null
                         && root.networks.length === 0
                text: root.connecting !== null ? "Connecting…" : "Scanning…"
                color: Theme.fg2
                font.family: "Adwaita Sans"
                font.pixelSize: 12
            }

            // The password prompt, in place of the list.
            Column {
                visible: root.pending !== null
                width: parent.width
                spacing: Tokens.space.s

                Pressable {
                    width: backLabel.implicitWidth + Tokens.space.s * 2
                    height: 24

                    onClicked: root.pending = null

                    Text {
                        id: backLabel
                        anchors.centerIn: parent
                        text: "‹ " + (root.pending ? root.pending.name : "")
                        color: Theme.gold
                        font.family: "Adwaita Sans"
                        font.pixelSize: 12
                        elide: Text.ElideRight
                        width: parent.width
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 36
                    radius: Tokens.radius.control
                    color: Theme.bg0
                    border.width: 1
                    border.color: password.activeFocus ? Theme.gold : Theme.bg2

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: Tokens.space.s
                        anchors.verticalCenter: parent.verticalCenter
                        visible: password.text.length === 0
                        text: "Password"
                        color: Theme.fg2
                        font.family: "Adwaita Sans"
                        font.pixelSize: 12
                    }

                    TextInput {
                        id: password

                        anchors.fill: parent
                        anchors.margins: Tokens.space.s
                        verticalAlignment: TextInput.AlignVCenter
                        echoMode: TextInput.Password
                        color: Theme.fg0
                        selectionColor: Theme.gold
                        selectedTextColor: Theme.bg0
                        // The caret in the neon: the greeter's convention.
                        cursorDelegate: Rectangle {
                            width: 2
                            radius: 1
                            color: Theme.teal
                            visible: password.cursorVisible
                        }
                        font.family: "Adwaita Sans"
                        font.pixelSize: 12

                        onAccepted: root.submit()

                        Keys.onEscapePressed: root.pending = null
                    }
                }

                Text {
                    text: "Enter to connect"
                    color: Theme.fg2
                    font.family: "Adwaita Sans"
                    font.pixelSize: 10
                }
            }

            // The failure line: red dot + fg0 text, on the section, not a
            // popup elsewhere.
            Row {
                visible: root.error !== ""
                spacing: Tokens.space.xs

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 6
                    height: 6
                    radius: 3
                    color: Theme.red
                }

                Text {
                    text: root.error
                    color: Theme.fg0
                    font.family: "Adwaita Sans"
                    font.pixelSize: 12
                }
            }
        }
    }
}
