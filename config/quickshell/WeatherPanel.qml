// The weather bubble, laid out as in the reference: three stacked cards.
// The first is the now (condition, a coloured icon and the temperature), the
// second the detail in four equally sized cells, the third the next five hours.
//
// The icons are emoji on purpose: Noto Color Emoji is installed, and its filled
// glyphs are the coloured look of the reference without drawing a set. The data
// is still one Open-Meteo request, shared with the bar pill through WeatherLine.
import QtQuick

Popup {
    id: root

    panelWidth: 300

    WeatherLine {
        id: weather

        width: parent.width
        showRow: false
    }

    // --- The now ----------------------------------------------------------
    Rectangle {
        width: parent.width
        radius: Tokens.radius.card
        color: Qt.rgba(Theme.bg2.r, Theme.bg2.g, Theme.bg2.b, 0.55)
        border.width: 1
        border.color: Qt.rgba(Theme.fg0.r, Theme.fg0.g, Theme.fg0.b, 0.07)

        implicitHeight: nowColumn.implicitHeight + 24

        Column {
            id: nowColumn

            anchors.centerIn: parent
            width: parent.width - 32
            spacing: 6

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: weather.condition === "" ? "…" : weather.condition
                color: Theme.fg2
                font.family: "Adwaita Sans"
                font.pixelSize: 11
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: weather.mood
                    font.pixelSize: 38
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: isNaN(weather.temp) ? "—" : Math.round(weather.temp) + "\u00b0"
                    color: Theme.fg0
                    font.family: "Adwaita Sans"
                    font.pixelSize: 46
                    font.weight: Font.DemiBold
                }
            }

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: weather.place
                color: Theme.fg2
                font.family: "Adwaita Sans"
                font.pixelSize: 10
            }
        }
    }

    // The cells size from the CONTENT width, not the window's: `width` here is
    // the full-screen window and the first attempt made 477 px cells.
    readonly property real detailCell:
        (root.panelWidth - Tokens.space.l * 2 - 4 * 3) / 4


    component Cell: Rectangle {
        id: cellBox

        property string glyph: ""
        property string value: "—"
        property string label: ""

        width: root.detailCell
        radius: Tokens.radius.control
        color: Qt.rgba(Theme.bg2.r, Theme.bg2.g, Theme.bg2.b, 0.55)
        border.width: 1
        border.color: Qt.rgba(Theme.fg0.r, Theme.fg0.g, Theme.fg0.b, 0.07)
        implicitHeight: cellColumn.implicitHeight + 18

        Column {
            id: cellColumn

            anchors.centerIn: parent
            width: parent.width - 8
            spacing: 4

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: cellBox.glyph
                color: Theme.fg1
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 14
            }

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: cellBox.value
                color: Theme.fg0
                font.family: "Adwaita Sans"
                font.pixelSize: 12
                font.bold: true
                font.features: ({ "tnum": 1 })
            }

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: cellBox.label
                color: Theme.fg2
                font.family: "Adwaita Sans"
                font.pixelSize: 9
            }
        }
    }

    // --- The detail: four cells -------------------------------------------
    Row {
        id: detail

        width: parent.width
        spacing: 4

        readonly property real cell: (width - spacing * 3) / 4


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

    // --- Now + the next four hours ----------------------------------------
    // The API starts at the NEXT hour, so "Now" is built here from the current
    // values; otherwise the first cell would say 22:00 at 21:14.
    readonly property var cells: weather.hours.length === 0 ? [] : [{
        time: "now",
        temp: weather.temp,
        emoji: weather.mood
    }].concat(weather.hours.slice(0, 4))

    Row {
        id: hourly

        width: parent.width
        spacing: 4

        readonly property real cell: (width - spacing * 4) / 5

        Repeater {
            model: root.cells

            delegate: Rectangle {
                id: hourBox

                required property var modelData
                required property int index

                width: hourly.cell
                radius: Tokens.radius.control
                color: Qt.rgba(Theme.bg2.r, Theme.bg2.g, Theme.bg2.b, 0.55)
                border.width: 1
                border.color: Qt.rgba(Theme.fg0.r, Theme.fg0.g, Theme.fg0.b, 0.07)
                implicitHeight: hourColumn.implicitHeight + 16

                Column {
                    id: hourColumn

                    anchors.centerIn: parent
                    width: parent.width - 6
                    spacing: 4

                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: isNaN(hourBox.modelData.temp)
                            ? "—" : Math.round(hourBox.modelData.temp) + "\u00b0"
                        color: Theme.fg0
                        font.family: "Adwaita Sans"
                        font.pixelSize: 12
                        font.bold: true
                        font.features: ({ "tnum": 1 })
                    }

                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: hourBox.modelData.emoji
                        font.pixelSize: 17
                    }

                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: {
                            if (hourBox.index === 0)
                                return "Now";
                            const t = hourBox.modelData.time;
                            return t && t.length >= 13 ? t.substring(11, 13) + ":00" : "—";
                        }
                        color: Theme.fg2
                        font.family: "Adwaita Sans"
                        font.pixelSize: 9
                    }
                }
            }
        }
    }
}
