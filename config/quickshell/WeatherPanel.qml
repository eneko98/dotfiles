// The weather bubble: the big temperature, a grid with the detail (feels like,
// wind, humidity, rain) and the next six hours, as in the reference. All of it
// comes from WeatherLine's single Open-Meteo request -- this file only lays the
// values out.
import QtQuick

Popup {
    id: root

    panelWidth: 340

    WeatherLine {
        id: weather

        width: parent.width
        showRow: false
    }

    // --- Now --------------------------------------------------------------
    Text {
        width: parent.width
        text: weather.condition === "" ? "…" : weather.condition
        color: Theme.fg1
        font.family: "Adwaita Sans"
        font.pixelSize: 12
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

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: weather.place
            color: Theme.fg2
            font.family: "Adwaita Sans"
            font.pixelSize: 11
        }
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Qt.rgba(Theme.fg0.r, Theme.fg0.g, Theme.fg0.b, 0.06)
    }

    // --- The detail: four equal columns ----------------------------------
    Row {
        id: detail

        width: parent.width
        spacing: 8

        readonly property real cell: (width - spacing * 3) / 4

        component Cell: Column {
            width: detail.cell
            spacing: 3

            property string glyph: ""
            property string value: "—"
            property string label: ""

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: parent.glyph
                color: Theme.fg1
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 15
            }

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: parent.value
                color: Theme.fg0
                font.family: "Adwaita Sans"
                font.pixelSize: 13
                font.bold: true
            }

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: parent.label
                color: Theme.fg2
                font.family: "Adwaita Sans"
                font.pixelSize: 10
            }
        }

        Cell {
            glyph: "󰔄"
            value: isNaN(weather.feels) ? "—" : Math.round(weather.feels) + "\u00b0"
            label: "Feels"
        }
        Cell {
            glyph: "󰖝"
            value: isNaN(weather.wind) ? "—" : Math.round(weather.wind) + " km/h"
            label: "Wind"
        }
        Cell {
            glyph: "󰖌"
            value: isNaN(weather.humidity) ? "—" : Math.round(weather.humidity) + "%"
            label: "Humidity"
        }
        Cell {
            glyph: "󰖗"
            value: isNaN(weather.rain) ? "—" : weather.rain.toFixed(1) + " mm"
            label: "Rain"
        }
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Qt.rgba(Theme.fg0.r, Theme.fg0.g, Theme.fg0.b, 0.06)
    }

    // --- The next six hours ----------------------------------------------
    Row {
        id: hourly

        width: parent.width
        spacing: 4

        readonly property real cell: (width - spacing * 5) / 6

        Repeater {
            model: weather.hours

            delegate: Column {
                required property var modelData

                width: hourly.cell
                spacing: 3

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: {
                        const t = modelData.time;
                        return t && t.length >= 13 ? t.substring(11, 13) + ":00" : "—";
                    }
                    color: Theme.fg1
                    font.family: "Adwaita Sans"
                    font.pixelSize: 11
                }

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: weather.info(modelData.code).glyph
                    color: Theme.fg1
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 14
                }

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: isNaN(modelData.temp) ? "—" : Math.round(modelData.temp) + "\u00b0"
                    color: Theme.fg0
                    font.family: "Adwaita Sans"
                    font.pixelSize: 12
                }
            }
        }
    }
}
