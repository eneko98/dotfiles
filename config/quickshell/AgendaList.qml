// The selected day's events under the calendar: 32 px rows -- "All day" (or
// a time when the events file ever carries one) in fg1, the title in fg0,
// and a bright dot when the row is a holiday. Empty state: "No events".
//
// `calendar` is the CalendarView instance that owns the events service.
import QtQuick

Column {
    id: root

    property var calendar: null
    property date selected: new Date()

    width: parent.width
    spacing: Tokens.space.xs

    readonly property var rows: {
        if (!calendar)
            return [];
        const key = calendar.dateKey(selected);
        const list = [];
        const holidays = calendar.holidaysForYear(selected.getFullYear())[key];

        if (holidays !== undefined)
            for (let i = 0; i < holidays.length; ++i)
                list.push({ text: holidays[i], holiday: true });

        const own = calendar.userEvents[key];
        if (own !== undefined) {
            if (Array.isArray(own))
                for (let j = 0; j < own.length; ++j)
                    list.push({ text: String(own[j]), holiday: false });
            else
                list.push({ text: String(own), holiday: false });
        }

        return list;
    }

    readonly property string label: Qt.formatDateTime(selected, "ddd d MMM")

    Text {
        text: root.label
        color: Theme.fg2
        font.family: "Adwaita Sans"
        font.pixelSize: 10
    }

    Repeater {
        model: root.rows

        delegate: Row {
            id: row

            required property var modelData

            width: root.width
            height: 32
            spacing: Tokens.space.s

            // The holiday dot; user events keep the space so titles align.
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 6
                height: 6
                radius: 3
                color: row.modelData.holiday ? Theme.fg0 : "transparent"
                border.width: row.modelData.holiday ? 0 : 1
                border.color: "transparent"
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "All day"
                color: Theme.fg1
                font.family: "Adwaita Sans"
                font.pixelSize: 11
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - x
                text: row.modelData.text
                color: Theme.fg0
                font.family: "Adwaita Sans"
                font.pixelSize: 13
                elide: Text.ElideRight
            }
        }
    }

    Text {
        visible: root.rows.length === 0
        text: "No events"
        color: Theme.fg1
        font.family: "Adwaita Sans"
        font.pixelSize: 12
    }
}
