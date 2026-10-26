import QtQuick

// Ghost pill for the user/session line.
Item {
    id: chip

    property alias text: label.text
    property bool interactive: true
    signal activated()

    implicitWidth: label.implicitWidth + 16
    implicitHeight: 26
    activeFocusOnTab: interactive && enabled

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab)
            Nav.keyboard = true;
        event.accepted = false;
    }
    Keys.onReturnPressed: if (chip.interactive && chip.enabled) chip.activated()
    Keys.onSpacePressed: if (chip.interactive && chip.enabled) chip.activated()

    Rectangle {
        anchors.fill: parent
        anchors.margins: -2
        radius: height / 2
        color: "transparent"
        border.width: 2
        border.color: Theme.gold
        visible: chip.activeFocus && Nav.keyboard
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2

        color: !chip.interactive || !chip.enabled ? "transparent"
             : mouse.pressed ? Qt.alpha(Theme.fg0, 0.10)
             : mouse.containsMouse ? Theme.bg2
             : "transparent"
    }

    Text {
        id: label

        anchors.centerIn: parent
        font.family: Config.fontSans
        font.pixelSize: 13

        color: !chip.enabled ? Theme.fg2
             : chip.interactive && (mouse.containsMouse || chip.activeFocus) ? Theme.fg0
             : Theme.fg1
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        enabled: chip.interactive && chip.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: Nav.keyboard = false
        onClicked: chip.activated()
    }
}
