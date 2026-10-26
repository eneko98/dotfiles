// The Today panel: what the island opens (brief 14.4). Two columns of 340
// under the island -- media and notifications on the left; the date, the
// weather line, the calendar and the selected day's agenda on the right.
// No panel title: the long date is the title. Each column scrolls on its
// own if the content does not fit; the panel is at most the space between
// the bar and the screen's bottom margin.
//
// `notifications` is the NotificationCenter instance, passed by the host
// (the server lives in the bar's process).
import Quickshell
import Quickshell.Services.Mpris
import QtQuick

Popup {
    id: root

    panelWidth: 736

    property var notifications: null

    // The card's player: the first one playing, else the first with a track
    // (a paused player can still be resumed from here). No player, no card.
    readonly property var player: {
        const players = Mpris.players.values;
        for (let i = 0; i < players.length; ++i)
            if (players[i].isPlaying)
                return players[i];
        for (let j = 0; j < players.length; ++j)
            if (players[j].trackTitle !== "")
                return players[j];
        return null;
    }

    readonly property real availableHeight: root.height - 54

    component ColumnScroll: Flickable {
        id: scroll

        property alias content: innerCol.data
        property alias spacing: innerCol.spacing

        width: 340
        height: Math.min(contentHeight, root.availableHeight)
        contentHeight: innerCol.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: innerCol
            width: 340
            spacing: 12
        }
    }

    Row {
        spacing: Tokens.space.l

        // --- Left: media + notifications --------------------------------
        ColumnScroll {
            content: [
                MediaCard {
                    width: 340
                    player: root.player
                    visible: root.player !== null
                    onScreen: root.visible
                },
                NotificationList {
                    width: 340
                    server: root.notifications
                }
            ]
        }

        // --- Right: the date and the calendar ---------------------------
        ColumnScroll {
            content: [
                Text {
                    width: 340
                    text: Qt.formatDateTime(clock.date, "dddd, d MMMM")
                    color: Theme.fg0
                    font.family: "Adwaita Sans"
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                },
                WeatherLine { width: 340 },
                CalendarView {
                    id: cal
                    width: 340
                    today: clock.date
                },
                AgendaList {
                    width: 340
                    calendar: cal
                    selected: cal.selected
                }
            ]
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
}
