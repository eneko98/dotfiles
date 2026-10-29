import QtQuick
import QtQuick.Effects
import Quickshell

// The greeter: background + scrim, the left column (date, big clock, user and
// session chips, password field, message line) and the power pills bottom
// right. Keyboard and mouse both work; focus rings only show for keyboard.
Item {
    id: root

    property real reveal: 0
    property bool launching: false

    Auth {
        id: auth
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Connections {
        target: auth

        function onPhaseChanged() {
            if (auth.phase === "launching")
                root.launching = true;
        }
    }

    Component.onCompleted: reveal = 1

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

    // Startup: black over the wallpaper, fading away with `reveal`.
    // On launch it fades back in before the greeter quits.
    Rectangle {
        anchors.fill: parent
        color: Theme.bg0
        opacity: root.launching ? 1 : 1 - root.reveal

        Behavior on opacity {
            SequentialAnimation {
                PauseAnimation { duration: root.launching ? 60 : 0 }
                NumberAnimation {
                    duration: root.launching ? Motion.base : Motion.slow
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: root.launching ? Motion.accel : Motion.standard
                }
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

        opacity: root.launching ? 0 : root.reveal
        y: (1 - root.reveal) * 12
        scale: 0.97 + 0.03 * root.reveal
        transformOrigin: Item.Center

        Behavior on opacity {
            SequentialAnimation {
                PauseAnimation { duration: 80 }
                NumberAnimation {
                    duration: root.launching ? Motion.fast : Motion.medium
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: root.launching ? Motion.accel : Motion.decel
                }
            }
        }

        Behavior on y {
            SequentialAnimation {
                PauseAnimation { duration: 80 }
                NumberAnimation {
                    duration: Motion.medium
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Motion.decel
                }
            }
        }

        Behavior on scale {
            SequentialAnimation {
                PauseAnimation { duration: 80 }
                NumberAnimation {
                    duration: Motion.medium
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Motion.decel
                }
            }
        }

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

            readonly property bool showError: kind === "error"

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                opacity: msgLine.showError ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Motion.fast
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: msgLine.showError ? Motion.decel : Motion.accel
                    }
                }

                Rectangle {
                    width: 6
                    height: 6
                    radius: 3
                    color: Theme.red
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: auth.message
                    color: Theme.fg0
                    font.family: Config.fontSans
                    font.pixelSize: 13
                    elide: Text.ElideRight
                    width: 346
                }
            }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                opacity: msgLine.showError ? 0 : 1

                Behavior on opacity {
                    NumberAnimation {
                        duration: Motion.fast
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: msgLine.showError ? Motion.accel : Motion.decel
                    }
                }

                Rectangle {
                    width: 6
                    height: 6
                    radius: 3
                    color: Theme.teal
                    visible: msgLine.kind === "caps"
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: msgLine.kind === "caps" ? "Caps Lock is on" : auth.message
                    color: msgLine.kind === "caps" ? Theme.teal : Theme.fg1
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

        opacity: root.launching ? 0 : root.reveal
        y: (1 - root.reveal) * 12

        Behavior on opacity {
            SequentialAnimation {
                PauseAnimation { duration: 120 }
                NumberAnimation {
                    duration: root.launching ? Motion.fast : Motion.medium
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: root.launching ? Motion.accel : Motion.decel
                }
            }
        }

        Behavior on y {
            SequentialAnimation {
                PauseAnimation { duration: 120 }
                NumberAnimation {
                    duration: Motion.medium
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Motion.decel
                }
            }
        }

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
