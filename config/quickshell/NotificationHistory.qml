// The notification history, opened from the bell. It lists everything the
// server is tracking (toasts that came and went included) and offers the two
// controls a history needs: do not disturb and clear all.
//
// A click on an entry dismisses that notification; the list shrinks live because
// the model is the server's ObjectModel.

import Quickshell
import QtQuick

Popup {
    id: root

    property var center: null

    panelWidth: 380

    Item {
        width: parent.width
        height: 20

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "Notifications"
            color: Theme.fg1
            font.family: "Source Han Serif CN"
            font.pixelSize: 12
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.center !== null && root.center.dnd ? "DND on" : "DND off"
            color: root.center !== null && root.center.dnd ? Theme.gold : Theme.fg2
            font.family: "Adwaita Sans"
            font.pixelSize: 10

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: if (root.center)
                    root.center.dnd = !root.center.dnd
            }
        }
    }

    Flickable {
        id: list

        visible: root.center !== null && root.center.tracked.values.length > 0
        width: parent.width
        height: Math.min(contentHeight, 360)
        contentHeight: listColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: listColumn

            width: list.width
            spacing: 6

            Repeater {
                model: root.center ? root.center.tracked : null

                delegate: Rectangle {
                    id: entry

                    required property var modelData

                    width: listColumn.width
                    implicitHeight: entryContent.implicitHeight + 16
                    radius: 6
                    color: Theme.bg2
                    border.width: 1
                    border.color: entryHover.containsMouse ? Theme.gold : "transparent"

                    Column {
                        id: entryContent

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 2

                        Text {
                            width: parent.width
                            visible: text !== ""
                            text: entry.modelData.appName
                            color: Theme.fg2
                            font.family: "Adwaita Sans"
                            font.pixelSize: 9
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            text: entry.modelData.summary
                            color: Theme.fg0
                            font.family: "Adwaita Sans"
                            font.pixelSize: 11
                            font.bold: true
                            elide: Text.ElideRight
                            textFormat: Text.PlainText
                        }

                        Text {
                            width: parent.width
                            visible: text !== ""
                            text: entry.modelData.body
                            color: Theme.fg1
                            font.family: "Adwaita Sans"
                            font.pixelSize: 10
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            textFormat: Text.PlainText
                        }
                    }

                    MouseArea {
                        id: entryHover

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (root.center)
                            root.center.dismiss(entry.modelData)
                    }
                }
            }
        }
    }

    Text {
        visible: root.center === null || root.center.tracked.values.length === 0
        text: "Nothing here"
        color: Theme.fg2
        font.family: "Adwaita Sans"
        font.pixelSize: 11
    }

    Text {
        visible: root.center !== null && root.center.tracked.values.length > 0
        text: "Clear all"
        color: clearHover.containsMouse ? Theme.gold : Theme.fg2
        font.family: "Adwaita Sans"
        font.pixelSize: 10

        MouseArea {
            id: clearHover

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: if (root.center)
                root.center.clearAll()
        }
    }
}
