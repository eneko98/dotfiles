// Caffeine toggle tile: same size and style as ToggleTile, but no detail panel.
import QtQuick

Pressable {
    id: root

    property bool checked: false

    width: 120
    height: 64
    pressScale: 0.97

    onClicked: root.checked = !root.checked

    Rectangle {
        id: body
        anchors.fill: parent
        radius: Tokens.radius.card
        color: root.checked
            ? Qt.rgba(Theme.gold.r, Theme.gold.g, Theme.gold.b, 0.18)
            : Qt.rgba(Theme.bg2.r, Theme.bg2.g, Theme.bg2.b, 0.60)

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Qt.rgba(Theme.fg0.r, Theme.fg0.g, Theme.fg0.b,
                           root.hovered ? 0.04 : 0)

            Behavior on color {
                ColorAnimation { duration: Motion.fast }
            }
        }

        Behavior on color {
            ColorAnimation { duration: Motion.fast }
        }

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            Glyph {
                anchors.verticalCenter: parent.verticalCenter
                glyph: "󰑷"
                size: 16
                tone: root.checked ? "active" : "normal"
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    text: "Caffeine"
                    color: Theme.fg0
                    font.family: "Adwaita Sans"
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }

                Text {
                    text: root.checked ? "On" : "Off"
                    color: Theme.fg1
                    font.family: "Adwaita Sans"
                    font.pixelSize: 10
                }
            }
        }
    }
}
