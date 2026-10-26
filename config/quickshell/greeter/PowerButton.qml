import QtQuick
import Quickshell.Io

Item {
    id: button

    property alias text: label.text
    property var command: []
    signal activated()

    implicitWidth: label.implicitWidth + 32
    implicitHeight: 32
    activeFocusOnTab: enabled

    function run() {
        if (Config.demo) {
            console.log("demo: would run", JSON.stringify(button.command));
            return;
        }
        proc.running = true;
    }

    Process {
        id: proc

        command: button.command
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab)
            Nav.keyboard = true;
        event.accepted = false;
    }
    Keys.onReturnPressed: if (enabled) button.run()
    Keys.onEnterPressed: if (enabled) button.run()
    Keys.onSpacePressed: if (enabled) button.run()

    readonly property bool focusRing: activeFocus && Nav.keyboard

    Rectangle {
        anchors.fill: parent
        anchors.margins: -2
        radius: height / 2
        color: "transparent"
        border.width: 2
        border.color: Qt.alpha(Theme.red, 0.55)
        visible: button.focusRing
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2

        color: !button.enabled ? Qt.alpha(Theme.bg1, 0.70)
             : mouse.pressed ? Theme.red
             : mouse.containsMouse ? Qt.alpha(Theme.red, 0.22)
             : Qt.alpha(Theme.bg1, 0.70)

        border.width: 1
        border.color: !button.enabled ? Qt.alpha(Theme.red, 0.15)
                    : mouse.pressed || mouse.containsMouse || button.focusRing ? Theme.red
                    : Qt.alpha(Theme.red, 0.35)
    }

    Text {
        id: label

        anchors.centerIn: parent
        font.family: Config.fontSans
        font.pixelSize: 12

        color: !button.enabled ? Theme.fg2
             : mouse.pressed ? Theme.bg0
             : mouse.containsMouse || button.focusRing ? Theme.fg0
             : Theme.fg1
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        enabled: button.enabled
        cursorShape: Qt.PointingHandCursor
        onPressed: Nav.keyboard = false
        onClicked: button.run()
    }
}
