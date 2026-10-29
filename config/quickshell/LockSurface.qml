// The lock screen's content: the wallpaper blurred and dimmed, a large serif
// clock, the date, the seal and the password field.
//
// It is a plain Rectangle so the same file works inside a WlSessionLockSurface
// (lock.qml, the real lock) and inside a FloatingWindow (lock-test.qml, where the
// layout and PAM can be tried without locking the session).
//
// The background is a pre-blurred copy of the current wallpaper: blurring a live
// screenshot inside QML would need a shader or the background-effect protocol,
// and the lock surface is not a normal layer surface. config/hypr/scripts/wallpaper
// regenerates it in XDG_STATE_HOME whenever a wallpaper is applied; on first boot
// there is none yet, so it falls back to the committed default (whose licence and
// derivation are in images/wallpapers/CREDITS.md).

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
            duration: Motion.slow
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.standard
        }
    }

    Component.onCompleted: reveal = 1

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    readonly property string lockWallpaper:
        Quickshell.env("HOME") + "/.local/state/dotfiles/lock-wallpaper.png"
    readonly property string defaultLockWallpaper:
        Quickshell.env("HOME") + "/repos/dotfiles/images/wallpapers/default-lock.png"

    Image {
        anchors.fill: parent
        source: root.lockWallpaper
        fillMode: Image.PreserveAspectCrop

        // First boot: the setter has not run, so there is no generated copy.
        onStatusChanged: if (status === Image.Error)
            source = root.defaultLockWallpaper
    }

    // A wash of bg0 so the text reads over the brightest bokeh.
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(Theme.bg0.r, Theme.bg0.g, Theme.bg0.b, 0.25)
    }

    // The entrance: black over the wallpaper, fading away with `reveal`.
    // On unlock it fades out again with base/accel after a 60 ms delay.
    Rectangle {
        anchors.fill: parent
        color: Theme.bg0
        opacity: root.context.dismissing ? 0 : (1 - root.reveal) * 0.8

        Behavior on opacity {
            SequentialAnimation {
                PauseAnimation { duration: root.context.dismissing ? 60 : 0 }
                NumberAnimation {
                    duration: root.context.dismissing ? Motion.base : Motion.slow
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: root.context.dismissing ? Motion.accel : Motion.standard
                }
            }
        }
    }

    Column {
        id: content

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        spacing: 18

        opacity: root.context.dismissing ? 0 : root.reveal
        y: (1 - root.reveal) * 12
        scale: 0.97 + 0.03 * root.reveal
        transformOrigin: Item.Center

        Behavior on opacity {
            NumberAnimation {
                duration: root.context.dismissing ? Motion.fast : Motion.medium
                easing.type: Easing.BezierSpline
                easing.bezierCurve: root.context.dismissing ? Motion.accel : Motion.decel
            }
        }

        Behavior on y {
            NumberAnimation {
                duration: root.context.dismissing ? Motion.fast : Motion.medium
                easing.type: Easing.BezierSpline
                easing.bezierCurve: root.context.dismissing ? Motion.accel : Motion.decel
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: Motion.medium
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.decel
            }
        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 2

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "hh:mm")
                color: Theme.fg0
                font.family: "Adwaita Sans"
                font.pixelSize: 96
                font.features: ({ "tnum": 1 })
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "dddd, d MMMM")
                color: Theme.fg1
                font.family: "Adwaita Sans"
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

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 280
            height: 40

            // Focus halo: a 1 px accent ring outside the field.
            Rectangle {
                anchors.fill: parent
                anchors.margins: -2
                radius: 10
                color: "transparent"
                border.width: 1
                border.color: root.context.showFailure ? Theme.red : Theme.gold
                opacity: password.activeFocus || root.context.showFailure ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Motion.fast
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Motion.standard
                    }
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: 8
                color: Qt.rgba(Theme.bg1.r, Theme.bg1.g, Theme.bg1.b, 0.92)
                border.width: 1
                border.color: root.context.showFailure ? Theme.red
                    : password.activeFocus ? Theme.gold
                    : Theme.bg2

                Behavior on border.color {
                    ColorAnimation {
                        duration: Motion.fast
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Motion.standard
                    }
                }

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
        }

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.max(normalMsg.implicitWidth, errorMsg.implicitWidth)
            height: Math.max(normalMsg.implicitHeight, errorMsg.implicitHeight)

            Text {
                id: normalMsg
                anchors.centerIn: parent
                text: root.context.unlockInProgress ? "Checking…"
                    : "Press Enter to unlock"
                color: Theme.fg2
                font.family: "Adwaita Sans"
                font.pixelSize: 10
                opacity: root.context.showFailure ? 0 : 1

                Behavior on opacity {
                    NumberAnimation {
                        duration: Motion.fast
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Motion.standard
                    }
                }
            }

            Text {
                id: errorMsg
                anchors.centerIn: parent
                text: "Incorrect password"
                color: Theme.red
                font.family: "Adwaita Sans"
                font.pixelSize: 10
                opacity: root.context.showFailure ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Motion.fast
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: root.context.showFailure
                            ? Motion.decel
                            : Motion.accel
                    }
                }
            }
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
