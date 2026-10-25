// The wifi popup: the radio switch, the visible networks sorted by signal, and
// a password field for a network we have never joined.
//
// WifiDevice.networks only holds what the scanner has found, so the scanner is
// enabled while the popup is open and switched off when it closes — otherwise it
// would keep the radio scanning for nothing.
//
// Connection is NetworkManager's: `connect()` for a known network (the backend
// already has the secret), `connectWithPsk()` for a new secured one. A failure
// comes back as `connectionFailed` on the network, which is where the red line
// at the bottom comes from.

import Quickshell
import Quickshell.Networking
import QtQuick

Popup {
    id: root

    panelWidth: 300

    readonly property var device: {
        const devices = Networking.devices.values;
        for (let i = 0; i < devices.length; ++i)
            if (devices[i].type === DeviceType.Wifi)
                return devices[i];
        return null;
    }

    // Connected first, then strongest. The list comes from `.values`, which is
    // the reactive view of the ObjectModel.
    readonly property var networks: {
        const d = root.device;
        const list = d ? d.networks.values.slice() : [];
        list.sort(function (a, b) {
            return (b.connected ? 1 : 0) - (a.connected ? 1 : 0)
                || b.signalStrength - a.signalStrength;
        });
        return list;
    }

    // The network waiting for a password, and the one a failure can come from.
    property var pending: null
    property var connecting: null
    property string error: ""

    onVisibleChanged: {
        if (root.device)
            root.device.scannerEnabled = root.visible;

        if (!root.visible) {
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

    function needsPsk(network) {
        return network.security === WifiSecurityType.WpaPsk
            || network.security === WifiSecurityType.Wpa2Psk
            || network.security === WifiSecurityType.Sae;
    }

    function activate(network) {
        root.error = "";

        if (network.connected)
            return;

        if (network.known || !needsPsk(network)) {
            root.connecting = network;
            network.connect();
            return;
        }

        root.pending = network;
        Qt.callLater(function () { password.forceActiveFocus(); });
    }

    function submit() {
        if (root.pending === null || password.text.length === 0)
            return;

        root.connecting = root.pending;
        root.pending.connectWithPsk(password.text);
        password.text = "";
        root.pending = null;
    }

    // --- Header: title and the radio switch --------------------------------
    Item {
        width: parent.width
        height: 18

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "Wi-Fi"
            color: Theme.fg1
            font.family: "Adwaita Sans"
            font.pixelSize: 11
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: Networking.wifiEnabled ? "On" : "Off"
            color: Networking.wifiEnabled ? Theme.gold : Theme.fg2
            font.family: "Adwaita Sans"
            font.pixelSize: 11

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
            }
        }
    }

    // --- Radio off ---------------------------------------------------------
    Text {
        visible: !Networking.wifiEnabled
        text: "Wi-Fi is off"
        color: Theme.fg2
        font.family: "Adwaita Sans"
        font.pixelSize: 11
    }

    // --- The network list --------------------------------------------------
    Flickable {
        id: list

        visible: Networking.wifiEnabled && root.pending === null
        width: parent.width
        height: Math.min(contentHeight, 320)
        contentHeight: networkColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: networkColumn
            width: list.width
            spacing: 2

            Repeater {
                model: root.networks

                delegate: Rectangle {
                    id: row

                    required property var modelData

                    width: networkColumn.width
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
                        text: row.modelData.connected ? "✓"
                            : row.modelData.stateChanging ? "…"
                            : root.needsPsk(row.modelData) ? ""
                            : ""
                        color: row.modelData.connected ? Theme.gold
                            : row.modelData.stateChanging ? Theme.teal
                            : Theme.fg2
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
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
        visible: Networking.wifiEnabled && root.pending === null && root.networks.length === 0
        text: "Scanning…"
        color: Theme.fg2
        font.family: "Adwaita Sans"
        font.pixelSize: 11
    }

    // --- Password prompt ---------------------------------------------------
    Item {
        visible: root.pending !== null
        width: parent.width
        implicitHeight: passwordColumn.implicitHeight

        Column {
            id: passwordColumn
            width: parent.width
            spacing: 8

            Text {
                text: "‹ " + (root.pending ? root.pending.name : "")
                color: Theme.gold
                font.family: "Adwaita Sans"
                font.pixelSize: 12
                elide: Text.ElideRight
                width: parent.width

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.pending = null
                }
            }

            Rectangle {
                width: parent.width
                height: 30
                radius: 4
                color: Theme.bg0
                border.width: 1
                border.color: password.activeFocus ? Theme.gold : Theme.bg2

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 6
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
                    anchors.margins: 6
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: TextInput.Password
                    color: Theme.fg0
                    selectionColor: Theme.gold
                    selectedTextColor: Theme.bg0
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
    }

    // --- Failure -----------------------------------------------------------
    Text {
        visible: root.error !== ""
        text: root.error
        color: Theme.red
        font.family: "Adwaita Sans"
        font.pixelSize: 11
    }
}
