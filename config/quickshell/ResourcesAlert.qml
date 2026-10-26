// The resources alert: the ONLY resource indicator on the bar, and it
// exists only while something is over the line (brief 9.3). The glyph says
// what (cpu / memory / temperature), the number says how much; red when
// critical. Click opens System's resources; the hover tooltip carries all
// three metrics.
import QtQuick

Item {
    id: root

    signal activated(string section)

    visible: Resources.alert !== ""
    width: alertRow.implicitWidth
    height: 30

    Pressable {
        id: press
        anchors.fill: parent

        onClicked: root.activated("resources")

        Row {
            id: alertRow
            anchors.centerIn: parent
            spacing: 4

            Glyph {
                anchors.verticalCenter: parent.verticalCenter
                glyph: Resources.alert === "temp" ? "󰔏"
                    : Resources.alert === "mem" ? "󰍛" : "󰻠"
                tone: Resources.alertCritical ? "alarm" : "bright"
                size: 14
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Resources.alert === "temp"
                    ? Math.round(Resources.tempC) + "°"
                    : Resources.alert === "mem"
                    ? Math.round(Resources.memUsed * 100) + "%"
                    : Math.round(Resources.cpu * 100) + "%"
                color: Resources.alertCritical ? Theme.red : Theme.fg0
                font.family: "Adwaita Sans"
                font.pixelSize: 12
                font.features: ({ "tnum": 1 })
            }
        }
    }

    Tooltip {
        hovered: press.hovered
        label: "CPU " + Math.round(Resources.cpu * 100) + "% · Mem "
            + Resources.memUsedGiB.toFixed(1) + " GB · "
            + (isNaN(Resources.tempC) ? "—" : Math.round(Resources.tempC) + "°C")
        below: false
        anchors.bottom: parent.top
        anchors.bottomMargin: Tokens.space.xs
        anchors.horizontalCenter: parent.horizontalCenter
    }
}
