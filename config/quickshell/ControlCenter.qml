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

    // --- Weather + calendar ----------------------------------------------
    // wttr.in over curl, no API key: it answers with the location, temperature
    // and condition for the caller's IP. Refreshed when the panel opens and
    // every 15 minutes while it stays open. A failed request shows a dash
    // instead of a stale promise.
    property string weatherText: "—"
    property string weatherLocation: ""
    property string weatherGlyph: "󰖐"
    property int monthOffset: 0

    readonly property date today: clock.date

    readonly property string monthLabel: Qt.formatDateTime(
        new Date(today.getFullYear(), today.getMonth() + monthOffset, 1), "MMMM yyyy")

    readonly property var monthDays: {
        const base = new Date(today.getFullYear(), today.getMonth() + monthOffset, 1);
        const year = base.getFullYear();
        const month = base.getMonth();
        const firstWeekday = (base.getDay() + 6) % 7;
        const daysInMonth = new Date(year, month + 1, 0).getDate();
        const cells = [];

        for (let i = 0; i < 42; ++i) {
            const date = new Date(year, month, i - firstWeekday + 1);
            cells.push({
                day: date.getDate(),
                inMonth: date.getMonth() === month,
                isToday: date.getFullYear() === today.getFullYear()
                    && date.getMonth() === today.getMonth()
                    && date.getDate() === today.getDate()
            });
        }

        return cells;
    }

    function weatherIcon(condition) {
        const c = condition.toLowerCase();

        if (c.indexOf("rain") >= 0 || c.indexOf("drizzle") >= 0 || c.indexOf("shower") >= 0)
            return "󰖗";
        if (c.indexOf("snow") >= 0 || c.indexOf("sleet") >= 0 || c.indexOf("blizzard") >= 0)
            return "󰖘";
        if (c.indexOf("thunder") >= 0)
            return "󰖓";
        if (c.indexOf("fog") >= 0 || c.indexOf("mist") >= 0 || c.indexOf("haze") >= 0)
            return "󰖑";
        if (c.indexOf("cloud") >= 0 || c.indexOf("overcast") >= 0)
            return "󰖐";
        if (c.indexOf("sun") >= 0 || c.indexOf("clear") >= 0)
            return "󰖙";
        return "󰖐";
    }

    function refreshWeather() {
        weatherQuery.running = false;
        weatherQuery.running = true;
    }

    Process {
        id: weatherQuery

        command: ["curl", "-fsS", "--max-time", "8", "https://wttr.in/?format=%l|%t|%C"]

        stdout: StdioCollector {
            id: weatherOut

            onStreamFinished: {
                const line = weatherOut.text.trim();
                if (line === "")
                    return;

                const parts = line.split("|");
                if (parts.length < 3)
                    return;

                root.weatherLocation = parts[0];
                root.weatherText = parts[1] + " · " + parts[2];
                root.weatherGlyph = root.weatherIcon(parts[2]);
            }
        }

        onExited: function (exitCode) {
            if (exitCode !== 0) {
                root.weatherText = "—";
                root.weatherLocation = "";
                root.weatherGlyph = "󰖐";
            }
        }
    }

    Timer {
        interval: 900000
        repeat: true
        running: root.visible
        onTriggered: root.refreshWeather()
    }

    onVisibleChanged: {
        if (!visible)
            return;

        brightnessRead.running = false;
        brightnessRead.running = true;
        root.refreshWeather();
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

    // --- Weather ----------------------------------------------------------
    ControlCard {
        width: parent.width
        glyph: root.weatherGlyph
        title: "Weather"
        detail: root.weatherLocation === ""
            ? root.weatherText
            : root.weatherText + " · " + root.weatherLocation
        onClicked: root.refreshWeather()
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

    // --- Calendar ---------------------------------------------------------
    Item {
        width: parent.width
        implicitHeight: calendarColumn.implicitHeight

        Column {
            id: calendarColumn
            width: parent.width
            spacing: 6

            Item {
                width: parent.width
                height: 18

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.monthLabel
                    color: Theme.fg1
                    font.family: "Source Han Serif CN"
                    font.pixelSize: 12

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.monthOffset = 0
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 14

                    Text {
                        text: "‹"
                        color: prevMonth.containsMouse ? Theme.gold : Theme.fg2
                        font.family: "Adwaita Sans"
                        font.pixelSize: 14

                        MouseArea {
                            id: prevMonth

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.monthOffset--
                        }
                    }

                    Text {
                        text: "›"
                        color: nextMonth.containsMouse ? Theme.gold : Theme.fg2
                        font.family: "Adwaita Sans"
                        font.pixelSize: 14

                        MouseArea {
                            id: nextMonth

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.monthOffset++
                        }
                    }
                }
            }

            Grid {
                id: weekdayGrid
                width: parent.width
                columns: 7

                Repeater {
                    model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

                    delegate: Text {
                        id: weekday

                        required property string modelData

                        width: weekdayGrid.width / 7
                        horizontalAlignment: Text.AlignHCenter
                        text: weekday.modelData
                        color: Theme.fg2
                        font.family: "Adwaita Sans"
                        font.pixelSize: 9
                    }
                }
            }

            Grid {
                id: dayGrid
                width: parent.width
                columns: 7
                rowSpacing: 2

                Repeater {
                    model: root.monthDays

                    delegate: Item {
                        id: dayCell

                        required property var modelData

                        width: dayGrid.width / 7
                        height: 22

                        Rectangle {
                            visible: dayCell.modelData.isToday
                            anchors.centerIn: parent
                            width: 20
                            height: 20
                            radius: 10
                            color: Theme.gold
                        }

                        Text {
                            anchors.centerIn: parent
                            text: dayCell.modelData.day
                            color: dayCell.modelData.isToday ? Theme.bg0
                                : dayCell.modelData.inMonth ? Theme.fg0
                                : Theme.fg2
                            font.family: "Adwaita Sans"
                            font.pixelSize: 10
                            font.bold: dayCell.modelData.isToday
                        }
                    }
                }
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
