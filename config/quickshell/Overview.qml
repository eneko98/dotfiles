// The workspace carousel: a Cover Flow of the existing workspaces, one card
// per workspace with a preview of its active window. The card in the middle
// is the current workspace; the others lean back with a Y rotation.
//
// Opened from the three-finger vertical gesture or SUPER+Tab, it closes with
// Escape, a click outside, or by selecting a card. A card previews the
// workspace's activated toplevel (or its first one) through ScreencopyView,
// captured once when the overview opens: live video for every window would be
// too much for a peek.
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

Popup {
    id: root

    panelWidth: 1100
    panelExtra: 0.3
    centerVertically: true

    // Special workspaces have a negative id and their own namespace; they are
    // not part of the carousel.
    readonly property var workspaces: Hyprland.workspaces.values.filter(w => w.id >= 0)
    readonly property int count: workspaces.length
    readonly property real cardWidth: 420

    property int current: 0
    // Continuous carousel position in cards (0 = current workspace centred).
    // Keyboard/step changes animate this; the drag sets it 1:1 with the finger.
    property real p: 0
    property real dragStartP: 0
    property bool dragging: false

    function syncCurrent() {
        for (let i = 0; i < workspaces.length; i++) {
            if (workspaces[i].focused) {
                current = i;
                return;
            }
        }
        current = 0;
    }

    function step(delta) {
        if (count === 0)
            return;
        const base = snap.running ? snap.to : current;
        const target = Math.max(0, Math.min(count - 1, base + delta));
        if (target === base)
            return;
        snap.stop();
        snap.duration = Motion.fast;
        snap.easing.bezierCurve = Motion.standard;
        snap.to = target;
        snap.start();
    }

    function select() {
        if (current >= 0 && current < count) {
            workspaces[current].activate();
            close();
        }
    }

    NumberAnimation {
        id: snap
        target: root
        property: "p"
        duration: Motion.medium
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Motion.decel
        onFinished: root.current = Math.round(root.p)
    }

    // The base Popup already owns onVisibleChanged (it arms the morph and
    // opens Panels), so this listens instead of overriding it. callLater
    // gives the base panel focus a chance to settle before the carousel takes
    // the arrow keys.
    Connections {
        target: root

        function onVisibleChanged() {
            if (root.visible) {
                root.syncCurrent();
                root.p = root.current;
                Qt.callLater(function () { carousel.forceActiveFocus(); });
            }
            root.updateStats();
        }
    }

    // --- Per-app numbers -----------------------------------------------------
    // cgstat.py writes one JSON line a second with every app scope's memory,
    // CPU, frozen flag and the PIDs inside it. A window's PID belongs to exactly
    // one scope, which is how a card finds its app. The helper only runs while
    // the carousel is open: those files are cheap to read, but nothing needs
    // them the rest of the time.
    property var appStats: ({})

    // The scope a window belongs to, found through its PID. Empty when the
    // window was not launched through uwsm (no scope of its own).
    function unitFor(pid) {
        for (const unit in root.appStats) {
            const pids = root.appStats[unit].pids;

            for (let i = 0; i < pids.length; ++i) {
                if (pids[i] === pid)
                    return unit;
            }
        }

        return "";
    }

    function statsFor(pid) {
        const unit = root.unitFor(pid);
        return unit === "" ? null : root.appStats[unit];
    }

    // --- The card menu -------------------------------------------------------
    // Right click on a card: freeze/thaw or kill the app behind its window.
    // `menu` holds the scope's unit and where to draw the little panel; null
    // means closed.
    property var menu: null
    readonly property int menuWidth: 168

    function openMenu(item, pointX, pointY) {
        root.menu = {
            unit: item.appUnit,
            app: item.appClass,
            frozen: item.appStats !== null && item.appStats.frozen,
            high: item.appStats !== null ? item.appStats.high : null,
            view: "root",
            x: pointX,
            y: pointY
        };
    }

    // Two views: the actions, and the memory caps (a third level would be a
    // menu for a menu; four presets is all this needs).
    readonly property var menuRows: {
        if (root.menu === null || root.menu.unit === "")
            return [];

        if (root.menu.view === "limit")
            return ["\u2039 Memory", "512 MB", "1 GB", "2 GB", "No cap"];

        return [root.menu.frozen ? "Thaw" : "Freeze", "Memory cap\u2026",
                "Kill app"];
    }

    function showView(view) {
        if (root.menu === null)
            return;

        const next = Object.assign({}, root.menu);
        next.view = view;
        root.menu = next;
    }

    function choose(label) {
        if (label === "Memory cap\u2026")
            return root.showView("limit");
        if (label === "\u2039 Memory")
            return root.showView("root");
        if (label === "Freeze" || label === "Thaw")
            return root.act(label === "Freeze" ? "freeze" : "thaw");
        if (label === "Kill app")
            return root.act("stop");
        if (label === "512 MB")
            return root.cap(536870912);
        if (label === "1 GB")
            return root.cap(1073741824);
        if (label === "2 GB")
            return root.cap(2147483648);
        if (label === "No cap")
            return root.cap(null);
    }

    // `MemoryHigh` throttles instead of killing: past the cap the app is slowed
    // (its pages get reclaimed), which is what you want on 5.7 GB -- MemoryMax
    // would just OOM-kill it. `--runtime` keeps it out of disk state.
    function cap(bytes) {
        if (root.menu === null)
            return;

        const unit = root.menu.unit;
        root.closeMenu();

        if (unit === "")
            return;

        Quickshell.execDetached(["systemctl", "--user", "set-property",
            "--runtime", unit,
            "MemoryHigh=" + (bytes === null ? "infinity" : String(bytes))]);
    }

    function closeMenu() {
        root.menu = null;
    }

    // systemctl --user is what systemd delegates the user's cgroup subtree for:
    // freeze stops every process in the scope, stop kills the whole tree and
    // takes the window with it.
    function act(action) {
        if (root.menu === null)
            return;

        const unit = root.menu.unit;
        root.closeMenu();

        if (unit === "")
            return;

        // Killing a frozen app is refused by systemd ("Cannot perform operation
        // on frozen unit"), so the kill thaws first. Both in one shell, because
        // two execDetached calls have no order between them.
        if (action === "stop") {
            Quickshell.execDetached(["sh", "-c", "systemctl --user thaw '"
                + unit + "'; systemctl --user stop '" + unit + "'"]);
        } else {
            Quickshell.execDetached(["systemctl", "--user", action, unit]);
        }
    }

    function memory(bytes) {
        if (bytes >= 1073741824)
            return (bytes / 1073741824).toFixed(1) + " GB";
        return Math.round(bytes / 1048576) + " MB";
    }

    function updateStats() {
        if (root.visible === stats.running)
            return;

        stats.running = root.visible;
        if (!root.visible)
            root.appStats = ({});
    }

    Timer {
        id: restart
        interval: 1000
        onTriggered: root.updateStats()
    }

    Process {
        id: stats

        command: ["python3",
            Quickshell.env("HOME") + "/.config/hypr/scripts/cgstat.py"]

        // If the helper dies (a bad /proc read, a scope vanishing mid-scan) the
        // cards must not stay blank for the rest of the session: while the
        // carousel is still open, start it again a second later.
        onExited: function (code, status) {
            if (root.visible)
                restart.start();
        }

        stderr: SplitParser {
            onRead: function (line) {
                console.log("cgstat: " + line);
            }
        }

        stdout: SplitParser {
            onRead: function (line) {
                try {
                    root.appStats = JSON.parse(line);
                } catch (error) {
                    // A half-written line is not worth a warning every second.
                }
            }
        }
    }

    Item {
        id: carousel

        width: parent.width
        height: 310

        focus: true

        Keys.onLeftPressed: root.step(-1)
        Keys.onRightPressed: root.step(1)
        Keys.onReturnPressed: root.select()
        Keys.onEnterPressed: root.select()
        Keys.onEscapePressed: root.menu !== null ? root.closeMenu() : root.close()

        Text {
            id: title

            text: "Workspaces"
            color: Theme.fg0
            font.family: "Adwaita Sans"
            font.pixelSize: 15
            font.bold: true
            anchors.left: parent.left
            anchors.top: parent.top
        }

        Text {
            text: "← →   ·   Enter   ·   Esc"
            color: Theme.fg2
            font.family: "Adwaita Sans"
            font.pixelSize: 11
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: 3
        }

        Item {
            id: cards

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: 40
            height: 260
            clip: false

            Repeater {
                model: root.workspaces

                delegate: Item {
                    id: cardItem

                    required property HyprlandWorkspace modelData
                    required property int index

                    readonly property real distance: index - root.p
                    // The window the card stands for: the activated one, or --
                    // while the panel itself holds the focus -- the one used
                    // most recently. Taking `list[0]` made the card describe a
                    // window the user had not touched in hours.
                    readonly property var preview: {
                        const list = modelData.toplevels.values;
                        let recent = null;

                        for (let i = 0; i < list.length; ++i) {
                            if (list[i].activated)
                                return list[i];

                            const ipc = list[i].lastIpcObject;
                            const age = ipc && ipc.focusHistoryID !== undefined
                                ? Number(ipc.focusHistoryID) : 9999;
                            const recentAge = recent && recent.lastIpcObject
                                && recent.lastIpcObject.focusHistoryID !== undefined
                                ? Number(recent.lastIpcObject.focusHistoryID) : 9999;
                            if (recent === null || age < recentAge)
                                recent = list[i];
                        }

                        return recent;
                    }
                    // The window's PID is the bridge to its app scope. The IPC
                    // object arrives key by key, so `pid` can be missing for a
                    // moment: coercing undefined into an `int` warns and leaves
                    // the property useless (measured: the card silently lost its
                    // numbers until this was guarded).
                    readonly property int pid: {
                        const ipc = preview !== null ? preview.lastIpcObject : null;
                        const value = ipc && ipc.pid !== undefined
                            ? Number(ipc.pid) : -1;
                        return isNaN(value) ? -1 : value;
                    }
                    readonly property string appClass: {
                        const ipc = preview !== null ? preview.lastIpcObject : null;
                        return ipc && ipc.class ? String(ipc.class) : "";
                    }
                    readonly property var appStats: root.statsFor(pid)
                    readonly property string appUnit: root.unitFor(pid)
                    // systemd escapes the "-" in "jail-kitty" as \x2d, so the
                    // scope reads app-...-jail\x2dkitty-<hash>.scope.
                    readonly property bool jailed: appUnit.indexOf("-jail\\x2d") !== -1

                    width: root.cardWidth
                    height: 260
                    x: {
                        const center = cards.width / 2 - root.cardWidth / 2;
                        const d = index - root.p;
                        let offset;
                        if (Math.abs(d) <= 1) {
                            offset = d * 0.55 * root.cardWidth;
                        } else {
                            offset = Math.sign(d) * (0.55 * root.cardWidth
                                + (Math.abs(d) - 1) * 0.25 * root.cardWidth);
                        }
                        return center + offset;
                    }
                    scale: {
                        const d = Math.abs(index - root.p);
                        return 1 - 0.16 * Math.min(d, 1)
                                 - 0.06 * Math.max(0, Math.min(d - 1, 1));
                    }
                    opacity: {
                        const d = Math.abs(index - root.p);
                        return 1 - 0.3 * Math.min(d, 2) / 2;
                    }
                    z: -Math.abs(index - root.p)

                    transform: Rotation {
                        origin.x: cardItem.width / 2
                        origin.y: cardItem.height / 2
                        axis { x: 0; y: 1; z: 0 }
                        angle: {
                            const d = index - root.p;
                            return -Math.sign(d) * 30 * Math.min(Math.abs(d), 1);
                        }
                    }

                    Surface {
                        id: card

                        anchors.fill: parent
                        level: 2
                        radius: 14
                        borderColor: cardItem.distance === 0
                            ? Theme.gold
                            : Qt.rgba(Theme.fg0.r, Theme.fg0.g, Theme.fg0.b, 0.12)
                    }

                    Item {
                        anchors.fill: parent
                        anchors.margins: 1
                        clip: true

                        ScreencopyView {
                            anchors.fill: parent
                            captureSource: root.visible && cardItem.preview
                                ? cardItem.preview.wayland : null
                            live: false
                            constraintSize: Qt.size(640, 360)
                        }

                        // A frozen app stops redrawing its window: the wash and
                        // the snowflake say "paused", not "broken".
                        Rectangle {
                            anchors.fill: parent
                            visible: cardItem.appStats !== null
                                && cardItem.appStats.frozen
                            color: Qt.rgba(Theme.bg0.r, Theme.bg0.g,
                                           Theme.bg0.b, 0.55)
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            anchors.topMargin: 18
                            visible: cardItem.appStats !== null
                                && cardItem.appStats.frozen
                            text: "\u2744"
                            color: Theme.teal
                            font.family: "Adwaita Sans"
                            font.pixelSize: 28
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: cardItem.preview === null
                            text: cardItem.modelData.name
                            color: Theme.fg2
                            font.family: "Adwaita Sans"
                            font.pixelSize: 56
                            font.bold: true
                        }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 72

                            gradient: Gradient {
                                GradientStop {
                                    position: 0.0
                                    color: Qt.rgba(Theme.bg0.r, Theme.bg0.g, Theme.bg0.b, 0.0)
                                }
                                GradientStop {
                                    position: 1.0
                                    color: Qt.rgba(Theme.bg0.r, Theme.bg0.g, Theme.bg0.b, 0.92)
                                }
                            }
                        }

                        Column {
                            anchors.left: parent.left
                            anchors.leftMargin: 14
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 12
                            spacing: 2

                            Row {
                                spacing: 6

                                Rectangle {
                                    width: 6
                                    height: 6
                                    radius: 3
                                    color: Theme.gold
                                    visible: cardItem.modelData.focused
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: "Workspace " + cardItem.modelData.name
                                    color: Theme.fg0
                                    font.family: "Adwaita Sans"
                                    font.pixelSize: 14
                                    font.bold: true
                                }
                            }

                            Text {
                                text: cardItem.modelData.toplevels.values.length === 1
                                    ? "1 window"
                                    : cardItem.modelData.toplevels.values.length + " windows"
                                color: Theme.fg1
                                font.family: "Adwaita Sans"
                                font.pixelSize: 11
                            }

                            // The app's own numbers, or nothing when it was not
                            // launched through uwsm (no scope of its own) --
                            // a dash would be noise, not information.
                            Text {
                                visible: cardItem.appStats !== null

                                text: {
                                    const s = cardItem.appStats;
                                    if (s === null)
                                        return "";

                                    const head = (s.frozen ? "frozen · " : "")
                                        + (cardItem.jailed ? "jail · " : "")
                                        + (cardItem.appClass
                                            ? cardItem.appClass + " · " : "");

                                    let line = head + root.memory(s.mem) + " · "
                                        + s.cpu + " %";

                                    if (s.high !== null && s.high !== undefined)
                                        line += " · cap " + root.memory(s.high);

                                    return line;
                                }
                                color: cardItem.jailed
                                    || (cardItem.appStats !== null
                                        && cardItem.appStats.frozen)
                                    ? Theme.teal : Theme.fg2
                                font.family: "Adwaita Sans"
                                font.pixelSize: 11
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        // Right click is a menu; the default is left-only, which
                        // is the trap that made the tray look dead.
                        acceptedButtons: Qt.LeftButton | Qt.RightButton

                        // The touchpad on this laptop never produces a right
                        // click (every press is the left button), so a long
                        // press opens the same menu.
                        onPressAndHold: function (mouse) {
                            const point = cardItem.mapToItem(carousel,
                                                             mouse.x, mouse.y);
                            root.openMenu(cardItem, point.x, point.y);
                        }

                        onClicked: function (mouse) {
                            // A long press that just opened the menu must not
                            // also jump to the workspace on release.
                            if (root.menu !== null)
                                return;

                            if (mouse.button === Qt.RightButton) {
                                const point = cardItem.mapToItem(carousel,
                                                                 mouse.x, mouse.y);
                                root.openMenu(cardItem, point.x, point.y);
                                return;
                            }

                            root.p = cardItem.index;
                            root.current = cardItem.index;
                            root.select();
                        }
                    }
                }
            }
        }

        // Two fingers and the wheel move the carousel; accepting no buttons
        // leaves the card clicks to the cards underneath.
        SwipeTracker {
            anchors.fill: parent

            // The shared tracker defaults to a full-width workspace swipe;
            // one card is much shorter, so the threshold follows the gesture.
            threshold: 0.06
            velocityThreshold: 0.2

            onMoved: function (offset) {
                if (!root.dragging) {
                    root.dragStartP = root.p;
                    root.dragging = true;
                }
                root.p = root.dragStartP - offset / root.cardWidth;
            }

            onSwiped: function (direction, velocity) {
                root.dragging = false;
                const target = Math.max(0, Math.min(root.count - 1,
                    root.current + (direction === "left" ? 1 : -1)));
                const distance = Math.abs(target - root.p) * root.cardWidth;
                snap.duration = Motion.release(distance, velocity,
                                                Motion.snapSlope, 160, 320);
                snap.easing.bezierCurve = Motion.snap;
                snap.to = target;
                snap.start();
            }

            onReleased: function (axis, velocity) {
                if (axis === "x") {
                    root.dragging = false;
                    const target = Math.max(0, Math.min(root.count - 1,
                                                        Math.round(root.p)));
                    const distance = Math.abs(target - root.p) * root.cardWidth;
                    snap.duration = Motion.release(distance, velocity,
                                                    Motion.snapSlope, 160, 320);
                    snap.easing.bezierCurve = Motion.snap;
                    snap.to = target;
                    snap.start();
                }
            }

            onWheeled: function (direction) {
                root.step(direction === "up" ? 1 : -1);
            }
        }

        // --- The card menu ---------------------------------------------------
        // Drawn inside the carousel on purpose: a second child of the Popup
        // root would land in its content column and grow the panel.
        Item {
            id: menuLayer

            anchors.fill: parent
            visible: root.menu !== null
            z: 10

            // Any click that is not on the menu closes it.
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onClicked: root.closeMenu()
            }

            Surface {
                id: menuPanel

                x: {
                    if (root.menu === null)
                        return 0;
                    return Math.max(0, Math.min(menuLayer.width - width,
                                                 root.menu.x - width / 2));
                }
                y: {
                    if (root.menu === null)
                        return 0;
                    return Math.min(menuLayer.height - height, root.menu.y + 8);
                }
                width: root.menuWidth
                height: menuColumn.implicitHeight + 8
                level: 3
                radius: 10

                Column {
                    id: menuColumn

                    anchors.centerIn: parent
                    width: parent.width - 8
                    spacing: 1

                    // No app scope: there is nothing to act on, so the menu
                    // says why instead of showing two rows that do nothing.
                    Text {
                        visible: root.menu !== null && root.menu.unit === ""
                        width: parent.width
                        leftPadding: 10
                        rightPadding: 10
                        topPadding: 7
                        bottomPadding: 7
                        text: "Not launched by uwsm. Restart the app to manage it."
                        wrapMode: Text.WordWrap
                        color: Theme.fg1
                        font.family: "Adwaita Sans"
                        font.pixelSize: 11
                    }

                    Repeater {
                        model: root.menuRows

                        delegate: Pressable {
                            id: row

                            required property string modelData

                            width: parent.width
                            height: 30
                            pressScale: 1.0

                            Rectangle {
                                anchors.fill: parent
                                radius: 6
                                color: row.hovered
                                    ? Qt.rgba(Theme.bg2.r, Theme.bg2.g,
                                              Theme.bg2.b, 0.9)
                                    : "transparent"
                            }

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                text: row.modelData
                                color: row.modelData === "Kill app"
                                    ? Theme.red : Theme.fg0
                                font.family: "Adwaita Sans"
                                font.pixelSize: 12
                            }

                            onClicked: root.choose(row.modelData)
                        }
                    }
                }
            }
        }
    }
}
