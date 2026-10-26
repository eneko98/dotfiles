// Month view with two-finger horizontal swipe (brief 10). Three month grids
// sit in a row inside a clipped item; a swipe moves the row 1:1 with the
// fingers, and release either snaps to the next/previous month (past 22% of
// the width, or a fast flick) or back to place. One swipe, one month.
//
// Axis lock: the first 8 px decide horizontal vs vertical; vertical is
// released to the panel's scroll. Shift+wheel changes months; plain wheel
// does not (it would fight the scroll). Fallbacks: the title's arrows, click
// the title for today, and the keyboard (arrows move the selection across
// months, PageUp/PageDown commit, Home returns to today).
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
    property string axis: ""
    property real _accX: 0
    property real _accY: 0
    property var _samples: []

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

    function commit(direction) {
        snap.to = -direction * cal.width;
        snap.direction = direction;
        snap.start();
    }

    function release() {
        const now = Date.now();
        const recent = cal._samples.filter(s => now - s.t < 80);
        const v = recent.length > 1
            ? (recent[recent.length - 1].dx - recent[0].dx)
              / Math.max(1, recent[recent.length - 1].t - recent[0].t)
            : 0;
        cal._samples = [];
        cal.axis = "";
        cal._accX = 0;
        cal._accY = 0;
        const far = Math.abs(cal.offset) > cal.width * 0.22;
        const fast = Math.abs(v) > 0.6 && Math.abs(cal.offset) > 12;
        if (far || fast)
            cal.commit(cal.offset < 0 ? 1 : -1);
        else {
            snap.to = 0;
            snap.direction = 0;
            snap.start();
        }
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

    // Gesture end: no events for 90 ms (libinput sends no kinetic scroll on
    // Wayland, so after the fingers lift nothing more arrives).
    Timer {
        id: idle
        interval: 90
        onTriggered: cal.release()
    }

    // The gesture, on a MouseArea (WheelHandler never fired in this stack --
    // measured with events arriving at a sibling MouseArea but not at the
    // handler, with and without acceptedDevices). acceptedButtons 0: the
    // wheel is handled here and clicks pass through to the cells. Vertical
    // gestures are released to the panel's scroll (accepted = false).
    MouseArea {
        anchors.fill: parent
        // No buttons: the wheel is handled here and clicks pass through to
        // the cells.
        acceptedButtons: Qt.NoButton

        onWheel: function (event) {
            const isWheel = event.pixelDelta.x === 0 && event.pixelDelta.y === 0;
            if (isWheel) {
                // Mouse wheel: vertical does not change months (it would
                // fight the panel's scroll); Shift+wheel does (brief 10.1).
                if (event.modifiers & Qt.ShiftModifier) {
                    if (snap.running)
                        snap.stop();
                    cal.commit(event.angleDelta.y > 0 ? -1 : 1);
                }
                return;
            }
            if (snap.running)
                snap.stop();
            const dx = event.inverted ? event.pixelDelta.x : -event.pixelDelta.x;
            const dy = event.pixelDelta.y;
            if (cal.axis === "") {
                cal._accX += Math.abs(dx);
                cal._accY += Math.abs(dy);
                if (cal._accX + cal._accY < 8) {
                    idle.restart();
                    return;
                }
                cal.axis = cal._accX >= cal._accY ? "x" : "y";
            }
            if (cal.axis === "y") {
                event.accepted = false;
                idle.restart();
                return;
            }
            cal.offset = Math.max(-cal.width, Math.min(cal.width, cal.offset + dx));
            cal._samples = cal._samples.concat([{ t: Date.now(), dx: cal.offset }]).slice(-8);
            idle.restart();
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
        if (!root.notifyToday)
            return;
        const key = root.dateKey(root.today);
        if (root.lastNotifiedKey === key)
            return;
        const events = root.eventsFor(root.today);
        if (events.length === 0)
            return;
        root.lastNotifiedKey = key;
        Quickshell.execDetached(["notify-send", "-a", "Calendar", "-i", "x-office-calendar",
            "Today", events.join(" · ")]);
    }

    Timer {
        interval: 5000
        running: root.notifyToday
        onTriggered: root.maybeNotifyToday()
    }

    Timer {
        interval: 60000
        repeat: true
        running: root.notifyToday
        onTriggered: root.maybeNotifyToday()
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
