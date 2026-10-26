import QtQuick

// 32x32 button inside the password field. `primary` = the accent submit button.
Item {
    id: button

    property string glyph: ""
    property bool primary: false
    property bool checked: false
    property bool busy: false
    signal activated()

    implicitWidth: 32
    implicitHeight: 32
    activeFocusOnTab: enabled

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab)
            Nav.keyboard = true;
        event.accepted = false;
    }
    Keys.onReturnPressed: if (enabled) button.activated()
    Keys.onEnterPressed: if (enabled) button.activated()
    Keys.onSpacePressed: if (enabled) button.activated()

    // Keyboard focus ring. Primary keeps a 2 px gap so it reads on the cyan fill.
    Rectangle {
        anchors.fill: parent
        anchors.margins: button.primary ? -4 : -2
        radius: 8 + (button.primary ? 4 : 2)
        color: "transparent"
        border.width: 2
        border.color: Theme.gold
        visible: button.activeFocus && Nav.keyboard
    }

    Rectangle {
        anchors.fill: parent
        radius: 8

        color: {
            if (button.busy)
                return Theme.bg2;
            if (button.primary && button.enabled)
                return mouse.pressed ? Qt.darker(Theme.gold, 1.12)
                     : mouse.containsMouse ? Qt.lighter(Theme.gold, 1.12)
                     : Theme.gold;
            if (button.checked)
                return Qt.alpha(Theme.gold, mouse.containsMouse ? 0.22 : 0.14);
            if (button.enabled && mouse.containsMouse)
                return Theme.bg2;
            return "transparent";
        }
    }

    Text {
        anchors.centerIn: parent
        text: button.busy ? "…" : button.glyph
        font.family: button.busy ? Config.fontSans : Config.fontIcons
        font.pixelSize: 14

        color: {
            if (button.busy)
                return Theme.fg1;
            if (!button.enabled)
                return Theme.fg2;
            if (button.primary)
                return Theme.bg0;
            if (button.checked)
                return Theme.gold;
            return mouse.containsMouse ? Theme.fg0 : Theme.fg1;
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        enabled: button.enabled
        cursorShape: Qt.PointingHandCursor
        onPressed: Nav.keyboard = false
        onClicked: button.activated()
    }
}
