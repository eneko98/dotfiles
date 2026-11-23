// The control centre: the status pill's panel. A row of section icons on top
// (the active one stretches into a pill with its name, as in the reference) and
// one section below, instead of the old column of accordions.
//
// The sections themselves are unchanged components (NetworkSection,
// BluetoothSection, SoundSection, DisplaySection, ResourcesSection, the tiles
// and the session row): this file only decides which one is on screen and keeps
// the network/bluetooth scanners alive exactly while their section is open.
import Quickshell
import Quickshell.Networking
import QtQuick

Popup {
    id: root

    // The dashboard is a wide, two-column section; the rest are one column.
    panelWidth: root.current === "dashboard" ? 860 : 520

    // The tabs are the control centre's own navigation. A panel opened straight
    // on one section (the dashboard, from the stats pill) has no need for them:
    // the pill already said what it wants.
    property bool showTabs: true

    property string section: ""
    readonly property string current: root.section === "" ? "network" : root.section

    // The notification server, passed by the shell (it lives in the bar's
    // process): the history is a section here now.
    property var notifications: null

    // The processes page, pushed over the sections from Resources' link.
    property bool showProcesses: false

    readonly property var tabs: [
        { id: "network", glyph: "󰖩", label: "Wi-Fi" },
        { id: "bluetooth", glyph: "󰂯", label: "Bluetooth" },
        { id: "sound", glyph: "󰕾", label: "Audio" },
        { id: "notifications", glyph: "󰂚", label: "Notifications" },
        { id: "display", glyph: "󰃠", label: "Display" },
        { id: "resources", glyph: "󰓅", label: "Resources" },
        { id: "session", glyph: "󰐥", label: "Session" }
    ]

    // Move between sections by one, wrapping. The wheel over the tab row and
    // the arrow keys use it; the IPC does too, which is how it gets tested
    // without a pointer.
    function step(delta) {
        const ids = root.tabs.map(t => t.id);
        let index = ids.indexOf(root.current);
        if (index < 0)
            index = 0;

        index = (index + delta + ids.length) % ids.length;
        root.section = ids[index];
    }

    function open(section) {
        root.section = section || "";
        root.showProcesses = false;
    }

    // Escape goes back from the processes page before closing the panel.
    function close() {
        if (root.showProcesses) {
            root.showProcesses = false;
            return;
        }
        root.closePanel();
    }

    // --- The sections row -------------------------------------------------
    // The wheel area is a SIBLING of the Row, not a child: an item with anchors
    // inside a positioner breaks its layout (the whole row vanished).
    Item {
        id: tabsBox

        visible: root.showTabs
        width: parent.width
        height: tabs.height

        Row {
        id: tabs

        width: parent.width
        spacing: 2

        Repeater {
            model: root.tabs

            delegate: Pressable {
                id: tab

                required property var modelData

                readonly property bool active: root.current === tab.modelData.id

                height: 30
                width: tabRow.implicitWidth + (tab.active ? 24 : 12)
                pressScale: 1.0

                Behavior on width {
                    NumberAnimation {
                        duration: Motion.fast
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Motion.standard
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 15
                    color: tab.active
                        ? Qt.rgba(Theme.bg2.r, Theme.bg2.g, Theme.bg2.b, 0.9)
                        : tab.hovered
                            ? Qt.rgba(Theme.bg2.r, Theme.bg2.g, Theme.bg2.b, 0.5)
                            : "transparent"
                }

                Row {
                    id: tabRow

                    anchors.centerIn: parent
                    spacing: 7

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: tab.modelData.glyph
                        color: tab.active ? Theme.gold : Theme.fg1
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 15
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: tab.active
                        text: tab.modelData.label
                        color: Theme.fg0
                        font.family: "Adwaita Sans"
                        font.pixelSize: 12
                    }
                }

                onClicked: root.section = tab.modelData.id === "system"
                    ? "" : tab.modelData.id
            }
        }
        }

        // On TOP of the row: a Pressable consumes wheel events (its own
        // MouseArea handles them), so behind it the two-finger scroll never
        // arrived. No buttons, so the clicks still reach the tabs.
        MouseArea {
            id: wheelArea

            anchors.fill: parent
            acceptedButtons: Qt.NoButton

            // A touchpad sends many small pixel deltas per gesture, a mouse one
            // 120 per notch: accumulate both and step once per notch.
            property real acc: 0

            onWheel: function (event) {
                // Either axis: a two-finger swipe can be horizontal and then
                // only pixelDelta.x is set.
                const dy = event.pixelDelta.y !== 0
                    ? event.pixelDelta.y : event.angleDelta.y / 120 * 40;
                const dx = event.pixelDelta.x !== 0
                    ? event.pixelDelta.x : event.angleDelta.x / 120 * 40;
                const d = Math.abs(dy) >= Math.abs(dx) ? dy : dx;

                wheelArea.acc += d;
                if (Math.abs(wheelArea.acc) < 40)
                    return;

                root.step(wheelArea.acc < 0 ? 1 : -1);
                wheelArea.acc = 0;
            }
        }
    }

    Rectangle {
        visible: root.showTabs
        width: parent.width
        height: 1
        color: Qt.rgba(Theme.fg0.r, Theme.fg0.g, Theme.fg0.b, 0.06)
    }

    // --- One section at a time -------------------------------------------
    // Declared as direct children so the Column sizes the panel to whichever is
    // visible; a Column ignores invisible children. There is no "System" page:
    // the tabs are the pages, so a grid of the same switches would only repeat
    // them. The switches live where they belong: night light in Display,
    // caffeine and lyrics in Session.
    NetworkSection {
        id: netSection

        width: parent.width
        showTile: false
        visible: root.current === "network"
        expanded: root.current === "network"
    }

    BluetoothSection {
        id: btSection

        width: parent.width
        showTile: false
        visible: root.current === "bluetooth"
        expanded: root.current === "bluetooth"
    }

    SoundSection {
        id: soundSection

        width: parent.width
        visible: root.current === "sound"
        expanded: root.current === "sound"
    }

    NotificationList {
        width: parent.width
        visible: root.current === "notifications"
        server: root.notifications
    }

    DisplaySection {
        width: parent.width
        visible: root.current === "display"
        showNightTile: true
    }

    ResourcesSection {
        width: parent.width
        visible: root.current === "resources"

        onProcessesRequested: root.showProcesses = true
    }

    DashboardSection {
        visible: root.current === "dashboard"
    }

    SessionRow {
        width: parent.width
        visible: root.current === "session"
    }

    ScenesRow {
        width: parent.width
        visible: root.current === "session"
    }

    Grid {
        width: parent.width
        columns: 2
        spacing: Tokens.space.s
        visible: root.current === "session"

        CaffeineTile {
            width: (parent.width - Tokens.space.s) / 2
            checked: Caffeine.active
            onCheckedChanged: Caffeine.active = checked
        }

        ToggleTile {
            width: (parent.width - Tokens.space.s) / 2
            expandable: false
            checked: Lyrics.enabled
            glyph: "\uf001"
            title: "Lyrics"
            subtitle: Lyrics.enabled
                ? (Lyrics.hasLyrics ? Lyrics.lines.length + " lines" : "On")
                : "Off"

            onToggled: {
                Lyrics.enabled = !Lyrics.enabled;
                Config.saveLyrics(Lyrics.enabled);
            }
        }
    }

    // The processes page: pushed over the sections (the overlay layer of
    // the stage), back with Escape or the header.
    overlay: SubPage {
        anchors.fill: parent
        active: root.showProcesses
        title: "Processes"

        onBack: root.showProcesses = false

        ProcessesPage {
            width: parent.width
        }
    }

    // --- Shared service reads --------------------------------------------
    readonly property var adapter: Bluetooth.defaultAdapter

    readonly property string networkName: {
        const devices = Networking.devices.values;
        for (let i = 0; i < devices.length; ++i) {
            if (devices[i].type !== DeviceType.Wifi)
                continue;
            const networks = devices[i].networks.values;
            for (let j = 0; j < networks.length; ++j)
                if (networks[j].connected)
                    return networks[j].name;
        }
        return "";
    }

    readonly property string btName: {
        if (!root.adapter)
            return "";
        const devices = root.adapter.devices.values;
        for (let i = 0; i < devices.length; ++i) {
            if (devices[i].connected)
                return devices[i].name;
        }
        return "";
    }
}
