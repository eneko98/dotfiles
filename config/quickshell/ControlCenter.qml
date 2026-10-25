// The control centre: what the island opens. One panel with the system's
// everyday levers — network, bluetooth, battery, night light, volume and
// brightness — and a way into the session menu.
//
// It is a Popup like the module popups, so the full-screen backdrop, Escape and
// exclusive keyboard focus come for free. The cards do not duplicate the module
// popups: network, bluetooth and battery emit signals that shell.qml forwards to
// the modules' openPopup(), and the panel closes first so only one backdrop is
// ever up.
//
// Volume is Pipewire.defaultAudioSink.audio; brightness is brightnessctl, read
// with `-m` when the panel opens and written through a 90 ms debounce so a drag
// does not spawn one process per pixel. Night light is hyprsunset's IPC.

import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import QtQuick

Popup {
    id: root

    panelWidth: 460

    signal networkRequested()
    signal bluetoothRequested()
    signal batteryRequested()
    signal sessionRequested()

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // --- Volume -----------------------------------------------------------
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var audio: sink ? sink.audio : null
    readonly property real volume: audio ? audio.volume : 0
    readonly property bool muted: audio ? audio.muted : false

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    // --- Wi-Fi ------------------------------------------------------------
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

    readonly property var wifi: wifiDevice()
    readonly property var network: connectedNetwork(wifi)

    // --- Bluetooth --------------------------------------------------------
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var btDevice: {
        if (!root.adapter)
            return null;
        const devices = root.adapter.devices.values;
        for (let i = 0; i < devices.length; ++i)
            if (devices[i].connected)
                return devices[i];
        return null;
    }

    // --- Battery ----------------------------------------------------------
    readonly property var battery: UPower.displayDevice
    readonly property bool batteryReady: battery ? battery.ready : false
    readonly property real batteryFraction: battery ? battery.percentage : 0

    function batteryGlyph() {
        if (root.batteryFraction >= 0.9)
            return "";
        if (root.batteryFraction >= 0.6)
            return "";
        if (root.batteryFraction >= 0.35)
            return "";
        if (root.batteryFraction >= 0.15)
            return "";
        return "";
    }

    readonly property string batteryDetail: {
        if (!root.battery || !root.batteryReady)
            return "";
        const pct = Math.round(root.batteryFraction * 100) + "%";
        const state = root.battery.state === UPowerDeviceState.Charging ? "Charging"
            : root.battery.state === UPowerDeviceState.FullyCharged ? "Full"
            : root.battery.state === UPowerDeviceState.Discharging ? "Discharging"
            : "";
        return state === "" ? pct : pct + " · " + state;
    }

    // --- Brightness -------------------------------------------------------
    property int brightness: 100
    property int pendingBrightness: -1

    Process {
        id: brightnessRead
        command: ["brightnessctl", "-m"]

        stdout: SplitParser {
            onRead: function (line) {
                const parts = line.trim().split(",");
                if (parts.length < 4)
                    return;
                const value = parseInt(parts[3]);
                if (!isNaN(value))
                    root.brightness = value;
            }
        }
    }

    Timer {
        id: brightnessDebounce
        interval: 90

        onTriggered: {
            if (root.pendingBrightness < 0)
                return;
            Quickshell.execDetached(["brightnessctl", "set", root.pendingBrightness + "%"]);
            root.pendingBrightness = -1;
        }
    }

    function setBrightness(fraction) {
        root.brightness = Math.max(1, Math.round(fraction * 100));
        root.pendingBrightness = root.brightness;
        brightnessDebounce.restart();
    }

    // --- Night light ------------------------------------------------------
    // hyprsunset has no queryable identity state (`profile` reports no profile
    // and `temperature` keeps the last value after identity), so the toggle owns
    // the state for the session.
    property bool nightLight: false

    function toggleNightLight() {
        root.nightLight = !root.nightLight;

        if (root.nightLight)
            Quickshell.execDetached(["hyprctl", "hyprsunset", "temperature", "4000"]);
        else
            Quickshell.execDetached(["hyprctl", "hyprsunset", "identity"]);
    }

    onVisibleChanged: {
        if (!visible)
            return;

        brightnessRead.running = false;
        brightnessRead.running = true;
    }

    // --- Header -----------------------------------------------------------
    Item {
        width: parent.width
        height: 22

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Seal {}

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "System"
                color: Theme.fg1
                font.family: "Source Han Serif CN"
                font.pixelSize: 12
            }
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatDateTime(clock.date, "ddd d MMM")
            color: Theme.fg2
            font.family: "Adwaita Sans"
            font.pixelSize: 10
        }
    }

    // The one hairline: gold at a third, under the header.
    Rectangle {
        width: parent.width
        height: 1
        color: Qt.rgba(Theme.gold.r, Theme.gold.g, Theme.gold.b, 0.35)
    }

    // --- Status cards -----------------------------------------------------
    Row {
        width: parent.width
        spacing: 10

        ControlCard {
            width: (parent.width - 10) / 2
            glyph: ""
            title: "Wi-Fi"
            detail: root.wifi && root.wifi.connected
                ? (root.network ? root.network.name : "Connected")
                : "Off"
            active: root.wifi ? root.wifi.connected : false
            onClicked: root.networkRequested()
        }

        ControlCard {
            width: (parent.width - 10) / 2
            glyph: ""
            title: "Bluetooth"
            detail: root.adapter && root.adapter.enabled
                ? (root.btDevice ? root.btDevice.name : "On")
                : "Off"
            active: root.btDevice !== null
            onClicked: root.bluetoothRequested()
        }
    }

    Row {
        width: parent.width
        spacing: 10

        ControlCard {
            width: (parent.width - 10) / 2
            glyph: root.batteryGlyph()
            title: "Battery"
            detail: root.batteryDetail
            active: root.battery && root.battery.state === UPowerDeviceState.Charging
            onClicked: root.batteryRequested()
        }

        ControlCard {
            width: (parent.width - 10) / 2
            glyph: "󰖔"
            title: "Night light"
            detail: root.nightLight ? "On" : "Off"
            active: root.nightLight
            onClicked: root.toggleNightLight()
        }
    }

    // --- Volume -----------------------------------------------------------
    Item {
        width: parent.width
        height: 22

        Text {
            id: volumeGlyph

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: root.muted ? "󰖁" : root.volume > 0.5 ? "󰕾" : root.volume > 0 ? "󰖀" : "󰕿"
            color: root.muted ? Theme.fg2 : Theme.fg1
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 15
        }

        Text {
            id: volumePct

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 34
            horizontalAlignment: Text.AlignRight
            text: Math.round(root.volume * 100) + "%"
            color: Theme.fg1
            font.family: "Adwaita Sans"
            font.pixelSize: 11
        }

        Slider {
            anchors.left: volumeGlyph.right
            anchors.leftMargin: 10
            anchors.right: volumePct.left
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            value: root.volume

            onMoved: function (value) {
                if (root.audio)
                    root.audio.volume = value;
            }
        }
    }

    // --- Brightness -------------------------------------------------------
    Item {
        width: parent.width
        height: 22

        Text {
            id: brightnessGlyph

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "󰃠"
            color: Theme.fg1
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 15
        }

        Text {
            id: brightnessPct

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 34
            horizontalAlignment: Text.AlignRight
            text: root.brightness + "%"
            color: Theme.fg1
            font.family: "Adwaita Sans"
            font.pixelSize: 11
        }

        Slider {
            anchors.left: brightnessGlyph.right
            anchors.leftMargin: 10
            anchors.right: brightnessPct.left
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            value: root.brightness / 100

            onMoved: function (value) {
                root.setBrightness(value);
            }
        }
    }

    // --- Session ----------------------------------------------------------
    ControlCard {
        width: parent.width
        height: 40
        glyph: ""
        title: "Session"
        detail: "Lock, log out, suspend, reboot, power off"
        onClicked: root.sessionRequested()
    }
}
