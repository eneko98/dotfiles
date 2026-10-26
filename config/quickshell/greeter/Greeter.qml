import QtQuick
import Quickshell

// Skeleton for the demo; the full "left axis" composition lands in the next
// commit. Clock + date + one password field wired to the demo auth.
Item {
    id: root

    Auth {
        id: auth
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Image {
        anchors.fill: parent
        source: Config.background
        fillMode: Image.PreserveAspectCrop
        cache: false
        sourceSize: Qt.size(1920, 1080)
    }

    MouseArea {
        anchors.fill: parent
        onClicked: input.forceActiveFocus()
    }

    Column {
        anchors.left: parent.left
        anchors.leftMargin: 128
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 96
        width: 360
        spacing: 12

        Text {
            text: clock.date.toLocaleDateString(Qt.locale("en_US"), "dddd, d MMMM")
            color: Theme.fg1
            font.family: Config.fontSans
            font.pixelSize: 20
            font.weight: Font.Medium
        }

        Text {
            text: Qt.formatTime(clock.date, "HH:mm")
            color: Theme.fg0
            font.family: Config.fontSans
            font.pixelSize: 128
            font.weight: Font.Bold
            font.letterSpacing: -3
        }

        Rectangle {
            width: 360
            height: 44
            radius: 10
            color: Qt.alpha(Theme.bg0, 0.85)
            border.width: 1
            border.color: input.activeFocus ? Theme.gold : Theme.bg2

            TextInput {
                id: input
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                verticalAlignment: TextInput.AlignVCenter
                focus: true
                echoMode: TextInput.Password
                passwordCharacter: "•"
                color: Theme.fg0
                font.family: Config.fontSans
                font.pixelSize: 15

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: input.text.length === 0 && input.preeditText.length === 0
                    text: "Password"
                    color: Theme.fg1
                    font: input.font
                }

                onAccepted: auth.submit(text)
            }
        }

        Text {
            height: 20
            text: auth.message
            color: auth.messageIsError ? Theme.fg0 : Theme.fg1
            font.family: Config.fontSans
            font.pixelSize: 13
            elide: Text.ElideRight
        }
    }
}
