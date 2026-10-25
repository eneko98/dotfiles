// A small seal: a gold square with the character knocked out in bg0, like a
// carved stamp. Used once, in the control centre header. The palette's red
// stays reserved for alarms; the identity mark is gold like the rest of the
// accents.

import QtQuick

Rectangle {
    width: 20
    height: 20
    radius: 3
    color: Theme.gold

    Text {
        anchors.centerIn: parent
        text: "墨"
        color: Theme.bg0
        font.family: "Source Han Serif CN"
        font.pixelSize: 12
        font.bold: true
    }
}
