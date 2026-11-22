// The clock bubble: what the island opens. The date, the analog clock, the
// month grid and the selected day's agenda -- nothing else. Media and weather
// have their own bubbles now, and the notification history moved to the control
// centre, so this is a calendar and not a dashboard.
import Quickshell
import QtQuick

Popup {
    id: root

    panelWidth: 372

    // Not root.height: a PanelWindow has no size until it is mapped, and the
    // Flickable then computed a negative height and the panel opened empty.
    readonly property real availableHeight: 720

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

    ColumnScroll {
        content: [
            Row {
                width: 340
                spacing: Tokens.space.m

                // The analog clock the user asked for: it ticks only while the
                // panel is open.
                AnalogClock {
                    anchors.verticalCenter: parent.verticalCenter
                    size: 44
                    running: root.visible
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    Text {
                        text: Qt.formatDateTime(clock.date, "dddd, d MMMM")
                        color: Theme.fg0
                        font.family: "Adwaita Sans"
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                    }

                    Text {
                        text: Qt.formatDateTime(clock.date, "hh:mm")
                        color: Theme.fg1
                        font.family: "Adwaita Sans"
                        font.pixelSize: 12
                        font.features: ({ "tnum": 1 })
                    }
                }
            },
            CalendarView {
                id: cal
                width: 340
                today: clock.date
                notifyToday: true
            },
            AgendaList {
                width: 340
                calendar: cal
                selected: cal.selected
            }
        ]
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
}
