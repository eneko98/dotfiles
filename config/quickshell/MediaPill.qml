// The media pill: the "now playing" wing of the bar, moved out of the island
// when the bar was split into pills. It holds what the island used to: the
// play/pause glyph, the spectrum and the current lyric line (or the track).
// The pill grows with its content, so a line of lyrics widens it -- that is the
// dynamic island, now on the media side.
//
// Clicking the glyph toggles playback; clicking the rest opens the media
// bubble (the pill's own MouseArea sits behind the content).
import Quickshell
import Quickshell.Services.Mpris
import QtQuick

Surface {
    id: root

    signal clicked()

    Media {
        id: media

        anchors.centerIn: parent
    }

    level: 1
    lifted: hover.hovered
    // Collapses to nothing with no player, so the bar does not show an empty
    // pill.
    width: media.active ? media.implicitWidth + 24 : 0
    height: 30
    opacity: media.active ? 1 : 0
    visible: media.active

    Behavior on width {
        NumberAnimation {
            duration: Motion.medium
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.standard
        }
    }

    HoverHandler { id: hover }

    MouseArea {
        anchors.fill: parent
        z: -1
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
