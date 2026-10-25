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
    // Open-Meteo needs coordinates instead of wttr.in's IP geolocation; these
    // are Barakaldo. Change both the place and the pair below if that moves.
    readonly property string weatherPlace: "Barakaldo"
    readonly property real weatherLatitude: 43.296
    readonly property real weatherLongitude: -2.988
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
                key: root.dateKey(date),
                inMonth: date.getMonth() === month,
                isToday: date.getFullYear() === today.getFullYear()
                    && date.getMonth() === today.getMonth()
                    && date.getDate() === today.getDate(),
                hasEvents: root.eventsFor(date).length > 0
            });
        }

        return cells;
    }

    // --- Calendar events --------------------------------------------------
    // Spain's national holidays are computed: the fixed dates plus Good Friday
    // (Easter - 2 days). Regional and local ones are not invented here; they go
    // in the events file, a date -> text map the user maintains:
    //   ~/.local/share/calendar/events.json
    // User data, untracked, reloaded when it changes.
    property var holidayCache: ({})
    property string selectedKey: ""
    property string lastNotifiedKey: ""

    readonly property string todayKey: root.dateKey(clock.date)

    FileView {
        id: eventsFile

        path: Quickshell.env("HOME") + "/.local/share/calendar/events.json"
        watchChanges: true
        printErrors: false

        onFileChanged: reload()
    }

    readonly property var userEvents: {
        const raw = eventsFile.text();

        if (raw === "" || raw.trim() === "")
            return ({});

        try {
            const data = JSON.parse(raw);
            return data !== null && typeof data === "object" ? data : ({});
        } catch (e) {
            return ({});
        }
    }

    function dateKey(date) {
        return date.getFullYear()
            + "-" + ("0" + (date.getMonth() + 1)).slice(-2)
            + "-" + ("0" + date.getDate()).slice(-2);
    }

    // Anonymous Gregorian algorithm (Meeus/Jones/Butcher).
    function easterDate(year) {
        const a = year % 19;
        const b = Math.floor(year / 100);
        const c = year % 100;
        const d = Math.floor(b / 4);
        const e = b % 4;
        const f = Math.floor((b + 8) / 25);
        const g = Math.floor((b - f + 1) / 3);
        const h = (19 * a + b - d - g + 15) % 30;
        const i = Math.floor(c / 4);
        const k = c % 4;
        const l = (32 + 2 * e + 2 * i - h - k) % 7;
        const m = Math.floor((a + 11 * h + 22 * l) / 451);
        const month = Math.floor((h + l - 7 * m + 114) / 31) - 1;
        const day = ((h + l - 7 * m + 114) % 31) + 1;

        return new Date(year, month, day);
    }

    function holidaysForYear(year) {
        if (root.holidayCache[year] !== undefined)
            return root.holidayCache[year];

        const map = {};
        const add = function (month, day, name) {
            const key = year + "-" + ("0" + month).slice(-2) + "-" + ("0" + day).slice(-2);

            if (map[key] === undefined)
                map[key] = [];
            map[key].push(name);
        };

        add(1, 1, "Año Nuevo");
        add(1, 6, "Epifanía");
        add(5, 1, "Fiesta del Trabajo");
        add(8, 15, "Asunción");
        add(10, 12, "Fiesta Nacional");
        add(11, 1, "Todos los Santos");
        add(12, 6, "Constitución");
        add(12, 8, "Inmaculada");
        add(12, 25, "Navidad");

        const easter = root.easterDate(year);
        const goodFriday = new Date(year, easter.getMonth(), easter.getDate() - 2);
        add(goodFriday.getMonth() + 1, goodFriday.getDate(), "Viernes Santo");

        root.holidayCache[year] = map;
        return map;
    }

    function eventsFor(date) {
        const key = root.dateKey(date);
        const events = [];
        const holidays = root.holidaysForYear(date.getFullYear())[key];

        if (holidays !== undefined)
            events.push.apply(events, holidays);

        const own = root.userEvents[key];
        if (own !== undefined) {
            if (Array.isArray(own))
                events.push.apply(events, own);
            else
                events.push(String(own));
        }

        return events;
    }

    readonly property date selectedDate: {
        const key = root.selectedKey === "" ? root.todayKey : root.selectedKey;
        const parts = key.split("-");
        return new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]));
    }

    readonly property var selectedEvents: root.eventsFor(root.selectedDate)
    readonly property string selectedLabel: Qt.formatDateTime(root.selectedDate, "ddd d MMM")

    function notifyToday() {
        if (root.lastNotifiedKey === root.todayKey)
            return;

        const events = root.eventsFor(clock.date);
        if (events.length === 0)
            return;

        root.lastNotifiedKey = root.todayKey;
        Quickshell.execDetached(["notify-send", "-a", "Calendar", "-i", "x-office-calendar",
            "Today", events.join(" · ")]);
    }

    Timer {
        interval: 5000
        running: true
        onTriggered: root.notifyToday()
    }

    Timer {
        interval: 60000
        repeat: true
        running: true
        onTriggered: root.notifyToday()
    }

    // WMO weather codes as Open-Meteo returns them: a label for the card and an
    // MDI glyph. Ranges collapse to the nearest condition.
    function weatherInfo(code) {
        if (code === 0)
            return { text: "Clear", glyph: "󰖙" };
        if (code === 1 || code === 2)
            return { text: "Partly cloudy", glyph: "󰖙" };
        if (code === 3)
            return { text: "Overcast", glyph: "󰖐" };
        if (code === 45 || code === 48)
            return { text: "Fog", glyph: "󰖑" };
        if (code >= 51 && code <= 57)
            return { text: "Drizzle", glyph: "󰖗" };
        if (code >= 61 && code <= 67)
            return { text: "Rain", glyph: "󰖗" };
        if (code >= 71 && code <= 77)
            return { text: "Snow", glyph: "󰖘" };
        if (code >= 80 && code <= 82)
            return { text: "Showers", glyph: "󰖗" };
        if (code === 85 || code === 86)
            return { text: "Snow showers", glyph: "󰖘" };
        if (code >= 95)
            return { text: "Thunderstorm", glyph: "󰖓" };
        return { text: "—", glyph: "󰖐" };
    }

    function refreshWeather() {
        weatherQuery.running = false;
        weatherQuery.running = true;
    }

    Process {
        id: weatherQuery

        command: ["curl", "-fsS", "--max-time", "8",
            "https://api.open-meteo.com/v1/forecast?latitude=" + root.weatherLatitude
            + "&longitude=" + root.weatherLongitude
            + "&current=temperature_2m,weather_code&timezone=auto"]

        stdout: StdioCollector {
            id: weatherOut

            onStreamFinished: {
                let data = null;

                try {
                    data = JSON.parse(weatherOut.text);
                } catch (e) {
                    return;
                }

                if (data === null || !data.current)
                    return;

                const info = root.weatherInfo(data.current.weather_code);
                root.weatherText = Math.round(data.current.temperature_2m) + "°C · " + info.text;
                root.weatherGlyph = info.glyph;
            }
        }

        onExited: function (exitCode) {
            if (exitCode !== 0) {
                root.weatherText = "—";
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
        detail: root.weatherText + " · " + root.weatherPlace
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

                        Rectangle {
                            visible: dayCell.modelData.hasEvents && !dayCell.modelData.isToday
                            anchors.bottom: parent.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 3
                            height: 3
                            radius: 1.5
                            color: Theme.gold
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.selectedKey = dayCell.modelData.key
                        }
                    }
                }
            }

            // The selected day's events, holidays included.
            Item {
                width: parent.width
                implicitHeight: selectedColumn.implicitHeight

                Column {
                    id: selectedColumn
                    width: parent.width
                    spacing: 2

                    Text {
                        text: root.selectedLabel
                        color: Theme.fg2
                        font.family: "Adwaita Sans"
                        font.pixelSize: 9
                    }

                    Text {
                        width: parent.width
                        text: root.selectedEvents.length > 0
                            ? root.selectedEvents.join(" · ")
                            : "No events"
                        color: root.selectedEvents.length > 0 ? Theme.fg0 : Theme.fg2
                        font.family: "Adwaita Sans"
                        font.pixelSize: 10
                        wrapMode: Text.Wrap
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
