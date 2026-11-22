// The weather, as a pill: glyph and degrees, nothing else (the reference bar's
// "27°"). The fetch and the WMO mapping live in WeatherLine, which the Today
// panel also uses, so there is one request behind both.
import QtQuick

Surface {
    id: root

    signal clicked()

    level: 1
    lifted: hover.hovered
    width: content.implicitWidth + 24
    height: 30

    HoverHandler { id: hover }

    MouseArea {
        anchors.fill: parent
        z: -1
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    WeatherLine {
        id: content

        compact: true
        anchors.centerIn: parent
    }
}
