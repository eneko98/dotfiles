// The toast stack: one card per recent notification, top right under the bar.
// Critical urgency takes the palette's red border, everything else gold.
//
// The window only exists while there is something to show. A card removes
// itself after its own timeout (the notification stays in the history), and a
// click dismisses the notification for good.

import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: root

    property var center: null

    anchors {
        top: true
        right: true
    }

    margins.top: 44
    margins.right: 14

    implicitWidth: 340
    implicitHeight: column.implicitHeight
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    visible: root.center !== null && root.center.toasts.count > 0

    Column {
        id: column

        anchors.fill: parent
        spacing: 8

        Repeater {
            model: root.center ? root.center.toasts : null

            delegate: Rectangle {
                id: card

                required property int index
                required property string summary
                required property string body
                required property string appName
                required property string appIcon
                required property int urgency
                required property int timeout
                required property int notificationId

                width: column.width
                implicitHeight: content.implicitHeight + 20
                radius: 8
                color: Qt.rgba(Theme.bg1.r, Theme.bg1.g, Theme.bg1.b, 0.96)
                border.width: 1
                border.color: card.urgency === NotificationUrgency.Critical ? Theme.red : Theme.gold

                Timer {
                    interval: Math.max(1, card.timeout) * 1000
                    running: true
                    onTriggered: if (root.center)
                        root.center.removeToast(card.notificationId)
                }

                Row {
                    id: content

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 10

                    Image {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: card.appIcon !== ""
                        width: 20
                        height: 20
                        source: card.appIcon === "" ? ""
                            : card.appIcon.startsWith("/") ? card.appIcon
                            : Quickshell.iconPath(card.appIcon)
                        sourceSize.width: 20
                        sourceSize.height: 20
                        fillMode: Image.PreserveAspectFit
                    }

                    Column {
                        width: content.width - (card.appIcon !== "" ? 30 : 0)
                        spacing: 2

                        Text {
                            width: parent.width
                            visible: text !== ""
                            text: card.appName
                            color: Theme.fg2
                            font.family: "Adwaita Sans"
                            font.pixelSize: 9
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            text: card.summary
                            color: Theme.fg0
                            font.family: "Adwaita Sans"
                            font.pixelSize: 12
                            font.bold: true
                            elide: Text.ElideRight
                            textFormat: Text.PlainText
                        }

                        Text {
                            width: parent.width
                            visible: text !== ""
                            text: card.body
                            color: Theme.fg1
                            font.family: "Adwaita Sans"
                            font.pixelSize: 11
                            wrapMode: Text.Wrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                            textFormat: Text.PlainText
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (root.center)
                        root.center.dismissToast(card.notificationId)
                }
            }
        }
    }
}
