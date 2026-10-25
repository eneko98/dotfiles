// A card in the control centre: a glyph, a title, a one-line detail, and a
// click. The border lights up in gold on hover, which is the whole affordance
// on a dark panel.

import QtQuick

Rectangle {
    id: root

    property string glyph: ""
    property string title: ""
    property string detail: ""
    property bool active: false

    signal clicked()

    height: 46
    radius: 8
    color: Theme.bg2
    border.width: 1
    border.color: hover.containsMouse ? Theme.gold : "transparent"

    Behavior on border.color {
        ColorAnimation { duration: 120 }
    }

    Text {
        id: glyphText

        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter

        text: root.glyph
        color: root.active ? Theme.gold : Theme.fg1
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 16
    }

    Column {
        anchors.left: glyphText.right
        anchors.leftMargin: 10
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        Text {
            width: parent.width
            text: root.title
            color: Theme.fg0
            font.family: "Adwaita Sans"
            font.pixelSize: 12
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            text: root.detail
            color: Theme.fg2
            font.family: "Adwaita Sans"
            font.pixelSize: 10
            elide: Text.ElideRight
        }
    }

    MouseArea {
        id: hover

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
