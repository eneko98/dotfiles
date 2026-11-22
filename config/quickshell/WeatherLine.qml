// One line of weather, not a card: glyph, "22 °C, partly cloudy" in fg0 and
// the place in fg1. The fetch is Open-Meteo over curl, no API key, fixed to
// these coordinates so nothing geolocates by IP. A failed request shows a
// dash instead of a stale promise. Refreshes on creation, when the host
// shows it, and every 15 minutes while visible.
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    // Barakaldo. Change the place and the pair together.
    readonly property string place: "Barakaldo"
    readonly property real latitude: 43.296
    readonly property real longitude: -2.988

    property string text: "—"
    property string glyph: "󰖐"
    property bool hovered: false
    // The bar pill wants the glyph and the degrees, nothing else.
    property bool compact: false
    // The bubble lays the values out its own way; the row is only for the pill
    // and for Today, so it can be turned off while the fetch keeps running.
    property bool showRow: true
    property real temp: NaN
    property string condition: ""

    // The detail the bubble shows; all of it comes from the same request.
    property real feels: NaN
    property real wind: NaN
    property real humidity: NaN
    property real rain: NaN
    property var hours: []
    property string mood: "🌡️"

    // The bubble turns the row off but still uses its values: with the row
    // hidden the item must not keep its 24 px, or the panel opens with a band
    // of empty space at the top.
    implicitHeight: root.showRow ? 24 : 0
    // The bar pill sizes itself from this; without it the width came out 0 and
    // the text hung outside the surface.
    implicitWidth: row.implicitWidth

    function refresh() {
        query.running = false;
        query.running = true;
    }

    onVisibleChanged: if (visible) root.refresh()

    // WMO codes as Open-Meteo returns them; ranges collapse to the nearest
    // condition.
    // The WMO code as a colour emoji too: Noto Color Emoji is installed and
    // gives the filled, coloured look of the reference without drawing icons.
    function emoji(code) {
        if (code === 0) return "☀️";
        if (code === 1 || code === 2) return "🌤️";
        if (code === 3) return "☁️";
        if (code === 45 || code === 48) return "🌫️";
        if (code >= 51 && code <= 57) return "🌦️";
        if (code >= 61 && code <= 67) return "🌧️";
        if (code >= 71 && code <= 77) return "🌨️";
        if (code >= 80 && code <= 82) return "🌦️";
        if (code === 85 || code === 86) return "🌨️";
        if (code >= 95) return "⛈️";
        return "🌡️";
    }

    function info(code) {
        if (code === 0) return { text: "Clear", glyph: "󰖙" };
        if (code === 1 || code === 2) return { text: "Partly cloudy", glyph: "󰖙" };
        if (code === 3) return { text: "Overcast", glyph: "󰖐" };
        if (code === 45 || code === 48) return { text: "Fog", glyph: "󰖑" };
        if (code >= 51 && code <= 57) return { text: "Drizzle", glyph: "󰖗" };
        if (code >= 61 && code <= 67) return { text: "Rain", glyph: "󰖗" };
        if (code >= 71 && code <= 77) return { text: "Snow", glyph: "󰖘" };
        if (code >= 80 && code <= 82) return { text: "Showers", glyph: "󰖗" };
        if (code === 85 || code === 86) return { text: "Snow showers", glyph: "󰖘" };
        if (code >= 95) return { text: "Thunderstorm", glyph: "󰖓" };
        return { text: "—", glyph: "󰖐" };
    }

    Component.onCompleted: root.refresh()

    Timer {
        interval: 900000
        repeat: true
        running: root.visible
        onTriggered: root.refresh()
    }

    Process {
        id: query

        command: ["curl", "-fsS", "--max-time", "8",
            "https://api.open-meteo.com/v1/forecast?latitude=" + root.latitude
            + "&longitude=" + root.longitude
            + "&current=temperature_2m,weather_code,apparent_temperature"
            + ",wind_speed_10m,relative_humidity_2m,precipitation"
            + "&hourly=temperature_2m,weather_code&forecast_hours=6"
            + "&timezone=auto"]

        stdout: StdioCollector {
            id: out

            onStreamFinished: {
                let data = null;

                try {
                    data = JSON.parse(out.text);
                } catch (e) {
                    return;
                }

                if (data === null || !data.current)
                    return;

                const info = root.info(data.current.weather_code);
                root.temp = data.current.temperature_2m;
                root.condition = info.text;
                root.mood = root.emoji(data.current.weather_code);
                root.text = Math.round(data.current.temperature_2m) + " °C · " + info.text;
                root.glyph = info.glyph;

                root.feels = data.current.apparent_temperature;
                root.wind = data.current.wind_speed_10m;
                root.humidity = data.current.relative_humidity_2m;
                root.rain = data.current.precipitation;

                const h = data.hourly;
                const list = [];
                if (h && h.time && h.temperature_2m) {
                    for (let i = 0; i < h.time.length && i < 6; ++i) {
                        const code = h.weather_code ? h.weather_code[i] : 0;
                        list.push({
                            time: h.time[i],
                            temp: h.temperature_2m[i],
                            code: code,
                            emoji: root.emoji(code)
                        });
                    }
                }
                root.hours = list;
            }
        }

        onExited: function (exitCode) {
            if (exitCode !== 0) {
                root.text = "—";
                root.temp = NaN;
                root.feels = NaN;
                root.wind = NaN;
                root.humidity = NaN;
                root.rain = NaN;
                root.hours = [];
                root.mood = "🌡️";
                root.glyph = "󰖐";
            }
        }
    }

    Row {
        id: row

        visible: root.showRow
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.compact ? 4 : Tokens.space.s

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.glyph
            color: Theme.fg1
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 14
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.compact
                ? (isNaN(root.temp) ? "—" : Math.round(root.temp) + "\u00b0")
                : root.text
            color: Theme.fg0
            font.family: "Adwaita Sans"
            font.pixelSize: root.compact ? 11 : 13
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: !root.compact
            text: root.place
            color: Theme.fg1
            font.family: "Adwaita Sans"
            font.pixelSize: 12
        }
    }
}
