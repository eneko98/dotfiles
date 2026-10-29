// Month view with two-finger horizontal swipe (brief 10). Three month grids
// sit in a row inside a clipped item; a swipe moves the row 1:1 with the
// fingers, and release either snaps to the next/previous month (past 22% of
// the width, or a fast flick) or back to place. One swipe, one month.
//
// Axis lock: the first 8 px decide horizontal vs vertical; vertical is
// released to the panel's scroll. The gesture itself is the shared
// SwipeTracker (same one the notification wing uses). Shift+wheel changes
// months; plain wheel does not (it would fight the scroll). Fallbacks: the
// title's arrows, click the title for today, and the keyboard (arrows move
// the selection across months, PageUp/PageDown commit, Home returns to today).
//
// The events service lives here: Spain's national holidays are computed
// (fixed dates + Good Friday from the Easter algorithm); everything else is
// the user's events file, a date -> text map reloaded on change:
//   ~/.local/share/calendar/events.json
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: cal

    property date selected: new Date()
    property date base: new Date()
    property date today: new Date()
    property real offset: 0

    readonly property real cellHeight: 34
    readonly property real headerHeight: 24

    implicitHeight: headerHeight + 18 + 6 * cellHeight
    clip: true
    focus: true

    // --- Events service ---------------------------------------------------
    property var holidayCache: ({})

    FileView {
        id: eventsFile

        path: Quickshell.env("HOME") + "/.local/share/calendar/events.json"
        watchChanges: true
        printErrors: false

        onFileChanged: reload()
    }

    readonly property var userEvents: {
        const raw = eventsFile.text();

        if (raw === "" || raw.trim() === "")
            return ({});

        try {
            const data = JSON.parse(raw);
            return data !== null && typeof data === "object" ? data : ({});
        } catch (e) {
            return ({});
        }
    }

    function dateKey(date) {
        return date.getFullYear()
            + "-" + ("0" + (date.getMonth() + 1)).slice(-2)
            + "-" + ("0" + date.getDate()).slice(-2);
    }

    // Anonymous Gregorian algorithm (Meeus/Jones/Butcher).
    function easterDate(year) {
        const a = year % 19;
        const b = Math.floor(year / 100);
        const c = year % 100;
        const d = Math.floor(b / 4);
        const e = b % 4;
        const f = Math.floor((b + 8) / 25);
        const g = Math.floor((b - f + 1) / 3);
        const h = (19 * a + b - d - g + 15) % 30;
        const i = Math.floor(c / 4);
        const k = c % 4;
        const l = (32 + 2 * e + 2 * i - h - k) % 7;
        const m = Math.floor((a + 11 * h + 22 * l) / 451);
        const month = Math.floor((h + l - 7 * m + 114) / 31) - 1;
        const day = ((h + l - 7 * m + 114) % 31) + 1;

        return new Date(year, month, day);
    }

    function holidaysForYear(year) {
        if (cal.holidayCache[year] !== undefined)
            return cal.holidayCache[year];

        const map = {};
        const add = function (month, day, name) {
            const key = year + "-" + ("0" + month).slice(-2) + "-" + ("0" + day).slice(-2);

            if (map[key] === undefined)
                map[key] = [];
            map[key].push(name);
        };

        add(1, 1, "Año Nuevo");
        add(1, 6, "Epifanía");
        add(5, 1, "Fiesta del Trabajo");
        add(8, 15, "Asunción");
        add(10, 12, "Fiesta Nacional");
        add(11, 1, "Todos los Santos");
        add(12, 6, "Constitución");
        add(12, 8, "Inmaculada");
        add(12, 25, "Navidad");

        const easter = cal.easterDate(year);
        const goodFriday = new Date(year, easter.getMonth(), easter.getDate() - 2);
        add(goodFriday.getMonth() + 1, goodFriday.getDate(), "Viernes Santo");

        cal.holidayCache[year] = map;
        return map;
    }

    function isHoliday(date) {
        return cal.holidaysForYear(date.getFullYear())[cal.dateKey(date)] !== undefined;
    }

    function eventsFor(date) {
        const key = cal.dateKey(date);
        const events = [];
        const holidays = cal.holidaysForYear(date.getFullYear())[key];

        if (holidays !== undefined)
            events.push.apply(events, holidays);

        const own = cal.userEvents[key];
        if (own !== undefined) {
            if (Array.isArray(own))
                events.push.apply(events, own);
            else
                events.push(String(own));
        }

        return events;
    }

    // --- Month machinery --------------------------------------------------
    function monthOffset(d, n) {
        return new Date(d.getFullYear(), d.getMonth() + n, 1);
    }

    readonly property string monthLabel: Qt.formatDateTime(cal.base, "MMMM yyyy")

    function commit(direction, velocity) {
        const target = -direction * cal.width;
        if (velocity === undefined) {
            snap.duration = Motion.medium;
            snap.easing.bezierCurve = Motion.decel;
        } else {
            const distance = Math.abs(target - cal.offset);
            snap.duration = Motion.release(distance, velocity,
                                            Motion.flingSlope, 160, 240);
            snap.easing.bezierCurve = Motion.fling;
        }
        snap.to = target;
        snap.direction = direction;
        snap.start();
    }

    function goToday() {
        cal.selected = new Date();
        cal.base = new Date(cal.selected.getFullYear(), cal.selected.getMonth(), 1);
    }

    onMonthLabelChanged: titleFade.restart()

    NumberAnimation {
        id: titleFade
        target: titleText
        property: "opacity"
        from: 0
        to: 1
        duration: Motion.fast
    }

    // The three grids: previous, current, next. x runs from -width so the
    // current month is under the view and the neighbours wait on the sides.
    Row {
        y: cal.headerHeight
        x: -cal.width + cal.offset

        Repeater {
            model: 3

            delegate: MonthGrid {
                width: cal.width
                height: 18 + 6 * cal.cellHeight
                month: cal.monthOffset(cal.base, index - 1)
                selected: cal.selected
                today: cal.today

                onPicked: function (d) {
                    cal.selected = d;
                }
            }
        }
    }

    NumberAnimation {
        id: snap

        property int direction: 0

        target: cal
        property: "offset"
        duration: Motion.medium
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Motion.decel

        onFinished: {
            if (direction !== 0) {
                cal.base = cal.monthOffset(cal.base, direction);
                cal.offset = 0;   // grids rebuild; visually continuous
            }
        }
    }

    // The gesture is the shared SwipeTracker: axis lock, samples and release
    // live there now. Shift+wheel changes months; a plain wheel does nothing
    // because vertical scroll belongs to the panel.
    SwipeTracker {
        id: swipe
        anchors.fill: parent
        threshold: 0.22

        onMoved: function (offset) {
            if (snap.running)
                snap.stop();
            cal.offset = Math.max(-cal.width, Math.min(cal.width, offset));
        }

        onSwiped: function (direction, velocity) {
            cal.commit(direction === "left" ? 1 : -1, velocity);
        }

        onReleased: function (axis, velocity) {
            if (axis !== "x")
                return;
            const distance = Math.abs(cal.offset);
            snap.duration = Motion.release(distance, velocity,
                                            Motion.flingSlope, 160, 240);
            snap.easing.bezierCurve = Motion.fling;
            snap.to = 0;
            snap.direction = 0;
            snap.start();
        }

        onWheeled: function (direction, modifiers) {
            if (!(modifiers & Qt.ShiftModifier))
                return;
            if (snap.running)
                snap.stop();
            cal.commit(direction === "up" ? -1 : 1);
        }
    }

    Keys.onPressed: function (event) {
        const d = new Date(cal.selected);
        switch (event.key) {
        case Qt.Key_Left:
            d.setDate(d.getDate() - 1);
            break;
        case Qt.Key_Right:
            d.setDate(d.getDate() + 1);
            break;
        case Qt.Key_Up:
            d.setDate(d.getDate() - 7);
            break;
        case Qt.Key_Down:
            d.setDate(d.getDate() + 7);
            break;
        case Qt.Key_PageUp:
            cal.commit(-1);
            event.accepted = true;
            return;
        case Qt.Key_PageDown:
            cal.commit(1);
            event.accepted = true;
            return;
        case Qt.Key_Home:
            cal.goToday();
            event.accepted = true;
            return;
        default:
            event.accepted = false;
            return;
        }
        const monthDiff = (d.getFullYear() - cal.base.getFullYear()) * 12
            + d.getMonth() - cal.base.getMonth();
        cal.selected = d;
        if (monthDiff !== 0)
            cal.commit(monthDiff > 0 ? 1 : -1);
        event.accepted = true;
    }

    // The "Today" toast: once per day (per session), through notify-send so
    // it goes through our own notification server and lands in the island
    // and the history. The host that wants it sets notifyToday.
    property bool notifyToday: false
    property string lastNotifiedKey: ""

    function maybeNotifyToday() {
        if (!cal.notifyToday)
            return;
        const key = cal.dateKey(cal.today);
        if (cal.lastNotifiedKey === key)
            return;
        const events = cal.eventsFor(cal.today);
        if (events.length === 0)
            return;
        cal.lastNotifiedKey = key;
        Quickshell.execDetached(["notify-send", "-a", "Calendar", "-i", "x-office-calendar",
            "Today", events.join(" · ")]);
    }

    Timer {
        interval: 5000
        running: cal.notifyToday
        onTriggered: cal.maybeNotifyToday()
    }

    Timer {
        interval: 60000
        repeat: true
        running: cal.notifyToday
        onTriggered: cal.maybeNotifyToday()
    }

    // The month header floats above the sliding grids: title centred, arrows
    // on the right (the fallback when there are no fingers on the pad).
    Item {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: cal.headerHeight

        Pressable {
            anchors.centerIn: parent
            width: titleText.implicitWidth + Tokens.space.s
            height: cal.headerHeight

            onClicked: cal.goToday()

            Text {
                id: titleText
                anchors.centerIn: parent
                text: cal.monthLabel
                color: Theme.fg0
                font.family: "Adwaita Sans"
                font.pixelSize: 15
                font.weight: Font.DemiBold
            }
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Tokens.space.xs

            Pressable {
                width: 28
                height: 28

                onClicked: cal.commit(-1)

                Text {
                    anchors.centerIn: parent
                    text: "‹"
                    color: parent.hovered ? Theme.gold : Theme.fg1
                    font.family: "Adwaita Sans"
                    font.pixelSize: 16
                }
            }

            Pressable {
                width: 28
                height: 28

                onClicked: cal.commit(1)

                Text {
                    anchors.centerIn: parent
                    text: "›"
                    color: parent.hovered ? Theme.gold : Theme.fg1
                    font.family: "Adwaita Sans"
                    font.pixelSize: 16
                }
            }
        }
    }

    // One month: the weekday header and the 42 cells.
    component MonthGrid: Item {
        id: grid

        property date month
        property date selected
        property date today
        signal picked(var d)

        readonly property var cells: {
            const year = month.getFullYear();
            const m = month.getMonth();
            const firstWeekday = (new Date(year, m, 1).getDay() + 6) % 7;
            const cells = [];

            for (let i = 0; i < 42; ++i) {
                const date = new Date(year, m, i - firstWeekday + 1);
                cells.push({
                    date: date,
                    day: date.getDate(),
                    key: cal.dateKey(date),
                    inMonth: date.getMonth() === m,
                    weekend: date.getDay() === 0 || date.getDay() === 6,
                    isToday: date.getFullYear() === today.getFullYear()
                        && date.getMonth() === today.getMonth()
                        && date.getDate() === today.getDate(),
                    isSelected: cal.dateKey(date) === cal.dateKey(selected),
                    hasEvents: cal.eventsFor(date).length > 0,
                    isHoliday: cal.isHoliday(date)
                });
            }

            return cells;
        }

        Column {
            anchors.fill: parent

            Grid {
                id: weekdayGrid
                width: parent.width
                columns: 7

                Repeater {
                    model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

                    delegate: Text {
                        required property string modelData

                        width: weekdayGrid.width / 7
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData
                        color: Theme.fg1
                        font.family: "Adwaita Sans"
                        font.pixelSize: 11
                    }
                }
            }

            Grid {
                id: dayGrid
                width: parent.width
                columns: 7

                Repeater {
                    model: grid.cells

                    delegate: Pressable {
                        id: cell

                        required property var modelData

                        width: dayGrid.width / 7
                        height: cal.cellHeight

                        onClicked: grid.picked(cell.modelData.date)

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 1
                            radius: Tokens.radius.control
                            color: cell.modelData.isToday ? Theme.gold
                                : cell.hovered ? Theme.bg2 : "transparent"
                            border.width: cell.modelData.isSelected && !cell.modelData.isToday ? 1 : 0
                            border.color: Theme.gold

                            Behavior on color {
                                ColorAnimation { duration: Motion.fast }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: cell.modelData.day
                            color: cell.modelData.isToday ? Theme.bg0
                                : !cell.modelData.inMonth ? Theme.fg2
                                : cell.modelData.weekend ? Theme.fg1 : Theme.fg0
                            font.family: "Adwaita Sans"
                            font.pixelSize: 11
                            font.bold: cell.modelData.isToday
                        }

                        // Event dot under the number; holidays carry the
                        // brighter one (no new colours).
                        Rectangle {
                            visible: cell.modelData.hasEvents && !cell.modelData.isToday
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 3
                            width: 4
                            height: 4
                            radius: 2
                            color: cell.modelData.isHoliday ? Theme.fg0 : Theme.fg1
                        }
                    }
                }
            }
        }
    }
}
