// CPU, temperature and memory in one pill: the reference bar's "3% | 59°C |
// 6.3GiB". It is read-only; the detail lives in the dashboard, which is what a
// click opens.
//
// The numbers come from the Resources singleton, the same one the dashboard and
// the HUD read, so there is a single sampling loop behind all of them.
import QtQuick

Surface {
    id: root

    signal clicked()

    level: 1
    lifted: hover.hovered
    width: row.implicitWidth + 24
    height: 30

    HoverHandler { id: hover }

    // The pill's padding is dead space otherwise.
    MouseArea {
        anchors.fill: parent
        z: -1
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    Row {
        id: row

        anchors.centerIn: parent
        spacing: 6

        Text {
            text: Math.round(Resources.cpu * 100) + "%"
            color: Theme.fg0
            font.family: "Adwaita Sans"
            font.pixelSize: 11
        }

        Text {
            visible: !isNaN(Resources.tempC)
            text: "\u00b7"
            color: Theme.fg2
            font.family: "Adwaita Sans"
            font.pixelSize: 11
        }

        Text {
            visible: !isNaN(Resources.tempC)
            text: Math.round(Resources.tempC) + "\u00b0"
            color: Theme.fg1
            font.family: "Adwaita Sans"
            font.pixelSize: 11
        }

        Text {
            text: "\u00b7"
            color: Theme.fg2
            font.family: "Adwaita Sans"
            font.pixelSize: 11
        }

        Text {
            // One decimal: "6.3G" is a glance, "6.27 GiB" is a dashboard.
            text: Resources.memUsedGiB.toFixed(1) + "G"
            color: Theme.fg1
            font.family: "Adwaita Sans"
            font.pixelSize: 11
        }
    }
}
