// The scene switcher in the System panel: Cine and Música. One active at a
// time; clicking the active one leaves it.
import QtQuick

Row {
    id: root

    spacing: Tokens.space.s

    Repeater {
        model: Scenes.names

        delegate: Pressable {
            required property string modelData

            width: (root.width - root.spacing * (Scenes.names.length - 1))
                / Scenes.names.length
            height: 34

            onClicked: Scenes.toggle(modelData)

            Rectangle {
                anchors.fill: parent
                radius: Tokens.radius.control
                color: Scenes.active === modelData
                    ? Qt.rgba(Theme.gold.r, Theme.gold.g, Theme.gold.b, 0.18)
                    : Qt.rgba(Theme.bg2.r, Theme.bg2.g, Theme.bg2.b, 0.85)
                border.width: 1
                border.color: Scenes.active === modelData
                    ? Theme.gold
                    : Qt.rgba(Theme.fg0.r, Theme.fg0.g, Theme.fg0.b, 0.10)

                Behavior on color {
                    ColorAnimation {
                        duration: Motion.fast
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Motion.standard
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                text: Scenes.definitions[modelData].label
                color: Scenes.active === modelData ? Theme.gold : Theme.fg1
                font.family: "Adwaita Sans"
                font.pixelSize: 12
            }
        }
    }
}
