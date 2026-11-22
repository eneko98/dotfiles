// The weather bubble: the big temperature and the condition, from the same
// Open-Meteo fetch WeatherLine already does (no second request). The hourly
// forecast of the reference is not here yet: this is the card the data we have
// can honestly fill.
import QtQuick

Popup {
    id: root

    panelWidth: 300

    WeatherLine {
        id: weather

        width: parent.width
        showRow: false
        // The visible instance is the one that fetches; the pill's own copy
        // shares the component but not the process, so this refreshes itself.
    }

    Row {
        width: parent.width
        spacing: 12

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: weather.glyph
            color: Theme.fg1
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 40
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: isNaN(weather.temp) ? "—" : Math.round(weather.temp) + "\u00b0"
            color: Theme.fg0
            font.family: "Adwaita Sans"
            font.pixelSize: 44
            font.bold: true
        }
    }

    Text {
        width: parent.width
        text: weather.condition === "" ? "…" : weather.condition
        color: Theme.fg1
        font.family: "Adwaita Sans"
        font.pixelSize: 14
    }

    Text {
        width: parent.width
        text: weather.place
        color: Theme.fg2
        font.family: "Adwaita Sans"
        font.pixelSize: 11
    }
}
