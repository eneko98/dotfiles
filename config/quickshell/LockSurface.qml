// The lock screen's content: the wallpaper blurred and dimmed, a large serif
// clock, the date, the seal and the password field.
//
// It is a plain Rectangle so the same file works inside a WlSessionLockSurface
// (lock.qml, the real lock) and inside a FloatingWindow (lock-test.qml, where the
// layout and PAM can be tried without locking the session).
//
// The background is a pre-blurred copy of the wallpaper: blurring a live
// screenshot inside QML would need a shader or the background-effect protocol,
// and the lock surface is not a normal layer surface. The file is generated from
// the CC0 original and recorded in images/wallpapers/CREDITS.md.
//
// The wallpaper path repeats the repo assumption hyprpaper already makes; when
// images/ is published at a stable XDG path, this is one of the places to change.

import Quickshell
import QtQuick

Rectangle {
    id: root

    required property LockContext context

    color: Theme.bg0

    // 0 while the surface is being mapped, 1 once it has settled. Everything
    // that appears is bound to it, so the lock fades in instead of snapping.
    property real reveal: 0

    Behavior on reveal {
        NumberAnimation {
            duration: 480
            easing.type: Easing.OutCubic
        }
    }

    Component.onCompleted: reveal = 1

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Image {
        anchors.fill: parent
        source: Quickshell.env("HOME") + "/repos/dotfiles/images/wallpapers/hong-kong-night-lock.png"
        fillMode: Image.PreserveAspectCrop
    }

    // A wash of bg0 so the text reads over the brightest bokeh.
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(Theme.bg0.r, Theme.bg0.g, Theme.bg0.b, 0.25)
    }

    // The entrance: black over the wallpaper, fading away with `reveal`.
    Rectangle {
        anchors.fill: parent
        color: Theme.bg0
        opacity: (1 - root.reveal) * 0.8
    }

    Column {
        id: content

        anchors.centerIn: parent
        spacing: 18

        opacity: root.context.dismissing ? 0 : root.reveal
        scale: 0.97 + 0.03 * root.reveal
        transformOrigin: Item.Center

        Behavior on opacity {
            NumberAnimation {
                duration: root.context.dismissing ? 220 : 480
                easing.type: root.context.dismissing ? Easing.InCubic : Easing.OutCubic
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: 480
                easing.type: Easing.OutCubic
            }
        }

        Seal {
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 2

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "hh:mm")
                color: Theme.fg0
                font.family: "Source Han Serif CN"
                font.pixelSize: 96
                font.features: ({ "tnum": 1 })
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "dddd, d MMMM")
                color: Theme.fg1
                font.family: "Source Han Serif CN"
                font.pixelSize: 17
            }
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 120
            height: 1
            color: Qt.rgba(Theme.gold.r, Theme.gold.g, Theme.gold.b, 0.35)
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 6

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "󰌾"
                color: Theme.fg2
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "eneko98"
                color: Theme.fg2
                font.family: "Adwaita Sans"
                font.pixelSize: 12
            }
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 280
            height: 40
            radius: 8
            color: Qt.rgba(Theme.bg1.r, Theme.bg1.g, Theme.bg1.b, 0.92)
            border.width: 1
            border.color: password.activeFocus ? Theme.gold : Theme.bg2

            Text {
                anchors.centerIn: parent
                visible: password.text.length === 0
                text: "Password"
                color: Theme.fg2
                font.family: "Adwaita Sans"
                font.pixelSize: 12
            }

            TextInput {
                id: password

                anchors.fill: parent
                anchors.margins: 12
                verticalAlignment: TextInput.AlignVCenter
                horizontalAlignment: TextInput.AlignHCenter
                echoMode: TextInput.Password
                enabled: !root.context.unlockInProgress
                focus: true
                color: Theme.fg0
                selectionColor: Theme.gold
                selectedTextColor: Theme.bg0
                font.family: "Adwaita Sans"
                font.pixelSize: 13
                inputMethodHints: Qt.ImhSensitiveData

                onTextChanged: root.context.currentText = text
                onAccepted: root.context.tryUnlock()

                Connections {
                    target: root.context

                    function onCurrentTextChanged() {
                        if (password.text !== root.context.currentText)
                            password.text = root.context.currentText;
                    }
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.context.showFailure ? "Incorrect password"
                : root.context.unlockInProgress ? "Checking…"
                : "Press Enter to unlock"
            color: root.context.showFailure ? Theme.red : Theme.fg2
            font.family: "Adwaita Sans"
            font.pixelSize: 10
        }
    }

    // The surface gets keyboard focus from the session lock; the retry covers the
    // moment before the window is active.
    Timer {
        interval: 300
        running: true
        onTriggered: password.forceActiveFocus()
    }

    Connections {
        target: root.context

        function onShowFailureChanged() {
            password.forceActiveFocus();
        }
    }
}
