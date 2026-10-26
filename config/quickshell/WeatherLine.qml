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

    implicitHeight: 24

    function refresh() {
        query.running = false;
        query.running = true;
    }

    onVisibleChanged: if (visible) root.refresh()

    // WMO codes as Open-Meteo returns them; ranges collapse to the nearest
    // condition.
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
            + "&current=temperature_2m,weather_code&timezone=auto"]

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
                root.text = Math.round(data.current.temperature_2m) + " °C · " + info.text;
                root.glyph = info.glyph;
            }
        }

        onExited: function (exitCode) {
            if (exitCode !== 0) {
                root.text = "—";
                root.glyph = "󰖐";
            }
        }
    }

    Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: Tokens.space.s

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.glyph
            color: Theme.fg1
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 14
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            color: Theme.fg0
            font.family: "Adwaita Sans"
            font.pixelSize: 13
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.place
            color: Theme.fg1
            font.family: "Adwaita Sans"
            font.pixelSize: 12
        }
    }
}
