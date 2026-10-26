// The System panel: what the status pill opens (brief 14.5). The battery as
// the header, the tile grid (Wi-Fi, Bluetooth, Night light) with at most one
// expanded detail underneath, sound, brightness, resources and the session
// row at the foot. The right edge is aligned with the pill that opened it;
// the trigger is set by the caller.
//
// The grid's tiles are the sections' own switches: expanding one closes the
// other, and the detail sections hide their tiles (the grid has them).
import Quickshell
import Quickshell.Networking
import QtQuick

Popup {
    id: root

    panelWidth: 400

    // Which detail is expanded under the tile grid: "" | "network" | "bt".
    property string expandedDetail: ""

    // The processes page, pushed over the sections from Resources' link.
    property bool showProcesses: false

    // The section to open/expand: "" | "sound" | "network" | "bluetooth" |
    // "battery" | "resources". Set by the shell from the status pill's
    // glyphs.
    property string section: ""

    onSectionChanged: applySection()
    Component.onCompleted: applySection()

    function applySection() {
        if (root.section === "network")
            root.expandedDetail = "network";
        else if (root.section === "bluetooth")
            root.expandedDetail = "bt";
        else if (root.section === "sound")
            soundSection.expanded = true;
        else if (root.section === "battery")
            batterySection.expanded = true;
    }

    // Escape goes back from the processes page before closing the panel.
    function close() {
        if (root.showProcesses) {
            root.showProcesses = false;
            return;
        }
        root.closePanel();
    }

    // The battery header, at full width.
    BatterySection {
        id: batterySection
        width: parent.width
    }

    // --- The tile grid ----------------------------------------------------
    Grid {
        width: parent.width
        columns: 2
        spacing: Tokens.space.s

        ToggleTile {
            width: (parent.width - Tokens.space.s) / 2
            checked: Networking.wifiEnabled
            glyph: "󰖩"
            title: "Wi-Fi"
            subtitle: Networking.wifiEnabled
                ? (root.networkName !== "" ? root.networkName : "On")
                : "Off"

            onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
            onExpandRequested: root.expandedDetail
                = root.expandedDetail === "network" ? "" : "network"
        }

        ToggleTile {
            width: (parent.width - Tokens.space.s) / 2
            checked: root.adapter ? root.adapter.enabled : false
            glyph: "\uf293"
            title: "Bluetooth"
            subtitle: root.adapter && root.adapter.enabled
                ? (root.btName !== "" ? root.btName : "On")
                : "Off"

            onToggled: {
                // The adapter object disappears while the radio is rfkill
                // blocked (the airplane key blocks it); the way back is
                // pkexec + polkit, which is its own confirmation dialog.
                if (root.adapter) {
                    console.log("BT tile toggled, enabled=", root.adapter.enabled);
                    root.adapter.enabled = !root.adapter.enabled;
                } else
                    Quickshell.execDetached(["pkexec", "rfkill", "unblock", "bluetooth"]);
            }
            onExpandRequested: root.expandedDetail
                = root.expandedDetail === "bt" ? "" : "bt"
        }

        ToggleTile {
            width: (parent.width - Tokens.space.s) / 2
            expandable: false
            checked: NightLight.on
            glyph: "󰖔"
            title: "Night light"
            subtitle: NightLight.on ? "4000 K" : "Off"

            onToggled: NightLight.toggle()
        }

        CaffeineTile {
            width: (parent.width - Tokens.space.s) / 2
            checked: Caffeine.active
            onCheckedChanged: Caffeine.active = checked
        }
    }

    // --- The one detail --------------------------------------------------
    // Both sections stay alive: their expanded handlers own the scanner and
    // the bt-agent lifecycle, and a destroyed section would leave them on.
    Item {
        width: parent.width
        height: root.expandedDetail === "network" ? netSection.implicitHeight
            : root.expandedDetail === "bt" ? btSection.implicitHeight
            : 0
        clip: true

        Behavior on height {
            NumberAnimation {
                duration: Motion.medium
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.standard
            }
        }

        NetworkSection {
            id: netSection
            width: parent.width
            showTile: false
            visible: root.expandedDetail === "network"
            expanded: root.expandedDetail === "network"
        }

        BluetoothSection {
            id: btSection
            width: parent.width
            showTile: false
            visible: root.expandedDetail === "bt"
            expanded: root.expandedDetail === "bt"
        }
    }

    // --- Zones: connections / devices / machine / session ----------------
    // The hairline dividers are written out three times; an inline
    // component here made the parser choke (Expected token ':').

    // --- The rows ---------------------------------------------------------
    Rectangle {
        width: parent.width
        height: 1
        color: Qt.rgba(Theme.fg0.r, Theme.fg0.g, Theme.fg0.b, 0.06)
    }

    SoundSection {
        id: soundSection
        width: parent.width
    }

    DisplaySection { width: parent.width; showNightTile: false }

    Rectangle {
        width: parent.width
        height: 1
        color: Qt.rgba(Theme.fg0.r, Theme.fg0.g, Theme.fg0.b, 0.06)
    }

    ResourcesSection {
        width: parent.width

        onProcessesRequested: root.showProcesses = true
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Qt.rgba(Theme.fg0.r, Theme.fg0.g, Theme.fg0.b, 0.06)
    }

    SessionRow { width: parent.width }

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
        for (let i = 0; i < devices.length; ++i)
            if (devices[i].connected)
                return devices[i].name;
        return "";
    }
}
