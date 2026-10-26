// An accordion section inside a panel: a 36 px header (name 13 SemiBold, a
// summary value in fg1 on the right, a chevron that turns 180 deg) and content
// that unfolds under it. Height animates over Motion.medium on the standard
// curve; the chevron turns over Motion.fast.
//
// Only one section expanded per panel is a panel-level rule: the panel wires
// `onExpandedChanged` to close the others (or binds `expanded` exclusively).
// Content lands in a Column below the header; it is clipped while the height
// animates.
import QtQuick

Column {
    id: root

    property string title: ""
    property string summary: ""
    property bool expanded: false
    property int headerHeight: 36

    default property alias content: contentCol.data

    width: parent.width

    Pressable {
        width: parent.width
        height: root.headerHeight

        onClicked: root.expanded = !root.expanded

        Row {
            anchors.left: parent.left
            anchors.leftMargin: Tokens.space.m
            anchors.right: parent.right
            anchors.rightMargin: Tokens.space.m
            anchors.verticalCenter: parent.verticalCenter
            spacing: Tokens.space.s

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - summaryText.width - chevron.width - Tokens.space.s * 2
                text: root.title
                color: Theme.fg0
                font.family: "Adwaita Sans"
                font.pixelSize: 13
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            Text {
                id: summaryText
                anchors.verticalCenter: parent.verticalCenter
                text: root.summary
                color: Theme.fg1
                font.family: "Adwaita Sans"
                font.pixelSize: 11
                elide: Text.ElideMiddle
                width: Math.min(implicitWidth, 120)
                horizontalAlignment: Text.AlignRight
            }

            Text {
                id: chevron
                anchors.verticalCenter: parent.verticalCenter
                text: "󰅂"
                color: Theme.fg1
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                rotation: root.expanded ? 90 : 0

                Behavior on rotation {
                    NumberAnimation {
                        duration: Motion.fast
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Motion.standard
                    }
                }
            }
        }
    }

    Item {
        id: contentClip
        width: parent.width
        height: root.expanded ? contentCol.height : 0
        clip: true

        Behavior on height {
            NumberAnimation {
                duration: Motion.medium
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.standard
            }
        }

        Column {
            id: contentCol
            width: parent.width
        }
    }
}
