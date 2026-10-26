// A toggle tile: 120x64, radius 12, two targets. The body toggles; the right
// 28 px (chevron) asks the owner to expand the section's detail. States:
//
//   off     bg2 60%   glyph fg1    title fg0   subtitle fg1 ("Off")
//   on      accent 18%   glyph accent title fg0  subtitle fg1 (SSID, device, K)
//   hover   a fg0 4% wash on top of either
//   pressed scale 0.97 (Pressable)
//   busy    like on/off + glyph at 60% opacity, subtitle "Connecting..." style
//   error   like off, subtitle in fg0 with a 6 px red dot
//
// Keyboard: Enter toggles, Right expands (handled here; the owner connects
// expandRequested to its detail view).
import QtQuick

Pressable {
    id: root

    property bool checked: false
    property bool busy: false
    property bool error: false
    property string glyph: ""
    property string title: ""
    // The owner's "on" subtitle; the tile shows "Off" while unchecked.
    property string subtitle: ""
    // Shown while busy (e.g. "Connecting..."); errorText wins when error.
    property string busyText: "Connecting..."
    property string errorText: "Failed"
    property int tileWidth: 120

    signal toggled()
    signal expandRequested()

    width: tileWidth
    height: 64
    pressScale: 0.97

    onClicked: root.toggled()

    Keys.onRightPressed: function (event) {
        root.expandRequested();
        event.accepted = true;
    }

    Rectangle {
        id: body
        anchors.fill: parent
        radius: Tokens.radius.card
        color: root.error || !root.checked
               ? Qt.rgba(Theme.bg2.r, Theme.bg2.g, Theme.bg2.b, 0.60)
               : Qt.rgba(Theme.gold.r, Theme.gold.g, Theme.gold.b, 0.18)

        // The hover wash, 4% fg0, on top of either base state.
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Qt.rgba(Theme.fg0.r, Theme.fg0.g, Theme.fg0.b,
                           root.hovered ? 0.04 : 0)

            Behavior on color {
                ColorAnimation { duration: Motion.fast }
            }
        }

        Behavior on color {
            ColorAnimation { duration: Motion.fast }
        }

        Row {
            id: contentRow

            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.right: expandZone.left
            anchors.rightMargin: 2
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            Glyph {
                id: icon
                anchors.verticalCenter: parent.verticalCenter
                glyph: root.glyph
                size: 16
                tone: root.error ? "alarm" : root.checked ? "active" : "normal"
                opacity: root.busy ? 0.6 : 1
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                // Explicit: the Row's width minus the glyph and spacing. A
                // Column sized from its children while a child sizes from
                // the Column is a binding loop -- the title elided to dots.
                width: contentRow.width - 16 - 6
                spacing: 2

                Text {
                    text: root.title
                    color: Theme.fg0
                    font.family: "Adwaita Sans"
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    width: parent.width
                }

                Item {
                    width: parent.width
                    height: 14

                    Text {
                        id: subtitleText
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        text: root.error ? root.errorText
                            : root.busy ? root.busyText
                            : root.checked ? root.subtitle : "Off"
                        color: root.error ? Theme.fg0 : Theme.fg1
                        font.family: "Adwaita Sans"
                        font.pixelSize: 10
                        elide: Text.ElideRight
                    }

                    // The error dot: red keeps its single meaning.
                    Rectangle {
                        visible: root.error
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: subtitleText.right
                        anchors.leftMargin: 4
                        width: 6
                        height: 6
                        radius: 3
                        color: Theme.red
                    }
                }
            }
        }

        // The expand zone: the right 28 px, with a chevron.
        Item {
            id: expandZone
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 24

            Text {
                anchors.centerIn: parent
                text: "󰅂"
                color: Theme.fg1
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.expandRequested()
            }
        }
    }
}
