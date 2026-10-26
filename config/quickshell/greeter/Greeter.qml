import QtQuick
import QtQuick.Effects
import Quickshell

// The greeter: background + scrim, the left column (date, big clock, user and
// session chips, password field, message line) and the power pills bottom
// right. Keyboard and mouse both work; focus rings only show for keyboard.
Item {
    id: root

    Auth {
        id: auth
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // ---------- background ----------

    Image {
        anchors.fill: parent
        source: Config.background
        fillMode: Image.PreserveAspectCrop
        cache: false
        sourceSize: Qt.size(1920, 1080)
    }

    // Bottom scrim: keeps the column readable on lighter wallpapers.
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: parent.height * 0.45

        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: "transparent"
            }

            GradientStop {
                position: 1.0
                color: Qt.alpha(Theme.bg0, 0.55)
            }
        }
    }

    // Clicking empty space returns focus to the password field.
    MouseArea {
        anchors.fill: parent

        onPressed: {
            Nav.keyboard = false;
            field.focusInput();
        }
    }

    // ---------- left column ----------

    Column {
        id: column

        anchors.left: parent.left
        anchors.leftMargin: 128
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 96
        width: 360
        spacing: 0

        Text {
            text: clock.date.toLocaleDateString(Qt.locale("en_US"), "dddd, d MMMM")
            color: Theme.fg1
            font.family: Config.fontSans
            font.pixelSize: 20
            font.weight: Font.Medium
            height: 28
            verticalAlignment: Text.AlignVCenter
        }

        Item {
            width: 1
            height: 4
        }

        Text {
            id: clockText

            x: -4   // optical: side bearing of the first digit at 128 px; tune from a capture
            text: Qt.formatTime(clock.date, "HH:mm")
            color: Theme.fg0
            font.family: Config.fontSans
            font.pixelSize: 128
            font.weight: Font.Bold        // match the lock screen clock
            font.letterSpacing: -3
            lineHeightMode: Text.FixedHeight
            lineHeight: 128

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "#000000"
                shadowOpacity: 0.45
                shadowBlur: 0.6
                shadowVerticalOffset: 2
            }
        }

        Item {
            width: 1
            height: 24
        }

        Row {
            id: chips

            x: -8   // align chip text with the field edge
            height: 26
            spacing: 8

            Chip {
                id: userChip

                visible: !userEdit.visible
                text: auth.user
                enabled: !auth.busy

                KeyNavigation.tab: sessionChip.interactive ? sessionChip : rebootButton
                KeyNavigation.backtab: field.submitItem

                onActivated: {
                    userEdit.text = auth.user;
                    userEdit.visible = true;
                    userEdit.forceActiveFocus();
                    userEdit.selectAll();
                }
            }

            // Inline editor for another user name.
            Rectangle {
                visible: userEdit.visible
                width: 160
                height: 26
                radius: 8
                color: Qt.alpha(Theme.bg0, 0.85)
                border.width: 1
                border.color: Theme.gold

                TextInput {
                    id: userEdit

                    visible: false
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    verticalAlignment: TextInput.AlignVCenter
                    clip: true
                    color: Theme.fg0
                    selectionColor: Qt.alpha(Theme.gold, 0.35)
                    selectedTextColor: Theme.fg0
                    font.family: Config.fontSans
                    font.pixelSize: 13

                    function close(apply) {
                        if (apply && text.trim().length > 0 && text.trim() !== auth.user) {
                            auth.user = text.trim();
                            auth.clearError();
                        }
                        visible = false;
                        field.focusInput();
                    }

                    Keys.onReturnPressed: close(true)
                    Keys.onEnterPressed: close(true)
                    Keys.onEscapePressed: close(false)
                    onActiveFocusChanged: if (!activeFocus && visible) close(false)
                }
            }

            Chip {
                id: sessionChip

                text: Config.sessionName
                interactive: false   // one session today; see the brief
            }
        }

        Item {
            width: 1
            height: 12
        }

        PasswordField {
            id: field

            auth: auth
            nextItem: userChip
            previousItem: poweroffButton

            Component.onCompleted: focusInput()
        }

        Item {
            width: 1
            height: 10
        }

        // Message line: always 20 px so nothing above moves.
        Item {
            id: msgLine

            width: 360
            height: 20

            readonly property string kind: {
                if (auth.phase === "error")
                    return "error";
                if (auth.message.length > 0)
                    return "info";
                if (CapsLock.on && field.inputItem.activeFocus)
                    return "caps";
                return "";
            }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Rectangle {
                    width: 6
                    height: 6
                    radius: 3
                    color: Theme.red
                    visible: msgLine.kind === "error"
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: msgLine.kind === "caps" ? "Caps Lock is on" : auth.message
                    color: msgLine.kind === "error" ? Theme.fg0
                         : msgLine.kind === "caps" ? Theme.teal
                         : Theme.fg1
                    font.family: Config.fontSans
                    font.pixelSize: 13
                    elide: Text.ElideRight
                    width: 346
                }
            }
        }
    }

    // ---------- power ----------

    Row {
        anchors.right: parent.right
        anchors.rightMargin: 128
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 132   // centre aligned with the password field
        spacing: 10

        PowerButton {
            id: rebootButton

            text: "Reboot"
            command: Config.rebootCommand
            enabled: !auth.busy

            KeyNavigation.tab: poweroffButton
            KeyNavigation.backtab: sessionChip.interactive ? sessionChip : userChip
        }

        PowerButton {
            id: poweroffButton

            text: "Power Off"
            command: Config.poweroffCommand
            enabled: !auth.busy

            KeyNavigation.tab: field.inputItem
            KeyNavigation.backtab: rebootButton
        }
    }
}
