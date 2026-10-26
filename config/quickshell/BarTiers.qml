// The tiers bar (layout B): workspaces on the left, the clock island in the
// centre, the status modules on the right -- three floating pills on a
// transparent 96 px window that reserves only the top 38 px.
//
// This file owns no shell objects: the shell (shell.qml) hands in the
// notification centre and learns about the user through signals; the morph
// triggers (island, statusPill) are aliased out because the panels grow out
// of them, and `islandHidden` / `pillHidden` come back the same way -- the
// shared-element rule lives with the panels, the pills just obey.
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

PanelWindow {
    id: bar

    // The morph triggers, for the panels that grow out of them.
    readonly property alias island: island
    readonly property alias statusPill: statusPill

    // The module popups, for the control centre's hand-offs (until the
    // layout switch retires them).
    readonly property alias volumeModule: volumeModule
    readonly property alias wifiModule: wifiModule
    readonly property alias bluetoothModule: bluetoothModule
    readonly property alias batteryModule: batteryModule

    // The notification centre, for the bell's counter and open action.
    property var notifications: null

    // Shared-element dips: the panel that grew out of a pill is up.
    property bool islandHidden: false
    property bool pillHidden: false

    // The island asks for Today; the shell opens the panel (it owns the
    // popup and the trigger wiring).
    signal todayRequested()

    anchors {
        top: true
        left: true
        right: true
    }

    // 96 px of canvas for shadows and (later) the expanded island, but
    // only the top 38 px are reserved: windows still start below 38.
    implicitHeight: 96
    exclusiveZone: 38
    color: "transparent"

    // A view into the system clock. Minutes precision is enough for a bar and
    // cheaper than Seconds: QML only recomputes the bound text when the minute
    // changes, with no timer and no process of our own.
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // Clicking a workspace circle switches to it. Hyprland's IPC dispatch takes
    // a Lua expression in 0.56 (usingLua), and the old token otherwise; keeping
    // both means the bar does not silently break if Hyprland is ever started
    // with a hyprlang config again.
    function focusWorkspace(workspaceId) {
        if (Hyprland.usingLua)
            Hyprland.dispatch("hl.dsp.focus({ workspace = " + workspaceId + " })");
        else
            Hyprland.dispatch("workspace " + workspaceId);
    }

    // Input follows the pills, not the window: clicks in the transparent
    // area (the shadow canvas) fall through to whatever is below. Each
    // Region tracks its item, so the mask follows the island as it grows.
    mask: Region {
        Region { item: workspacesPill }
        Region { item: island }
        Region { item: statusPill }
    }

    // --- Left pill: the workspaces -------------------------------------
    // One circle per existing workspace, the focused one in gold. A plain
    // Repeater: Hyprland.workspaces is a live model, and the circle's size
    // never changes, so nothing needs a layout.
    Surface {
        id: workspacesPill
        level: 1
        lifted: workspacePillHover.hovered

        anchors.left: parent.left
        anchors.top: parent.top
        anchors.topMargin: Tokens.space.xs
        anchors.leftMargin: 14

        width: workspaces.implicitWidth + 16
        height: 30

        HoverHandler { id: workspacePillHover }

        Behavior on width {
            NumberAnimation {
                duration: Motion.medium
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.standard
            }
        }

        Row {
            id: workspaces
            anchors.centerIn: parent
            spacing: 2

            Repeater {
                model: Hyprland.workspaces

                delegate: Rectangle {
                    required property var modelData

                    width: 22
                    height: 22
                    radius: 11
                    color: modelData.focused ? Theme.gold
                        : workspaceHover.containsMouse ? Theme.bg2
                        : "transparent"

                    Behavior on color {
                        ColorAnimation { duration: Motion.fast }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: modelData.id
                        color: modelData.focused ? Theme.bg0 : Theme.fg1
                        font.family: "Adwaita Sans"
                        font.pixelSize: 11
                        font.bold: modelData.focused
                    }

                    MouseArea {
                        id: workspaceHover

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: bar.focusWorkspace(modelData.id)
                    }
                }
            }
        }
    }

    // --- Centre: the island --------------------------------------------
    // The time is the one place the clock gets a voice; the date stays
    // small and sans so the hierarchy is time first, date second. The
    // island is e2: the one surface that lifts a level on hover.
    Surface {
        id: island
        level: 2
        lifted: islandArea.containsMouse

        // The Today panel grows out of this surface; while its window
        // is up the island hides so there are never two copies (it comes
        // back only when the return morph has finished).
        opacity: bar.islandHidden ? 0 : 1

        Behavior on opacity {
            NumberAnimation { duration: Motion.fade }
        }

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Tokens.space.xs
        width: clockRow.implicitWidth + 24
        height: 30

        // Growing with the media section is the island's whole trick; make
        // it a slide rather than a jump.
        Behavior on width {
            NumberAnimation {
                duration: Motion.medium
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.standard
            }
        }

        // Declared before the row so the play button inside Media sits
        // above it: later items win the click.
        MouseArea {
            id: islandArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: bar.todayRequested()
        }

        // "88:88" measures the widest case so the island keeps one width and
        // does not breathe every minute. tnum helps when the font has it,
        // the fixed width covers the case where it does not.
        TextMetrics {
            id: timeMetrics
            font.family: "Adwaita Sans"
            font.pixelSize: 15
            font.bold: true
            font.features: ({ "tnum": 1 })
            text: "88:88"
        }

        Row {
            id: clockRow
            anchors.centerIn: parent
            spacing: 8

            // The dynamic part: shows while a player has a track.
            Media {
                id: media
            }

            Rectangle {
                visible: media.active
                width: 1
                height: 14
                color: Theme.bg2
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatDateTime(clock.date, "hh:mm")
                width: timeMetrics.width
                horizontalAlignment: Text.AlignHCenter
                color: Theme.fg0
                font.family: "Adwaita Sans"
                font.pixelSize: 15
                font.bold: true
                // Tabular figures: the clock must not breathe every minute.
                font.features: ({ "tnum": 1 })
            }

            // The date steps aside while the media section is up.
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: !media.active
                text: Qt.formatDateTime(clock.date, "ddd d MMM")
                color: Theme.fg1
                font.family: "Adwaita Sans"
                font.pixelSize: 11
            }
        }

    }

    // --- Right pill: the status modules --------------------------------
    Surface {
        id: statusPill
        level: 1
        lifted: statusPillHover.hovered

        // The System panel grows out of this pill; it hides while the
        // panel is up, same shared-element rule as the island.
        opacity: bar.pillHidden ? 0 : 1

        Behavior on opacity {
            NumberAnimation { duration: Motion.fade }
        }

        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: Tokens.space.xs
        anchors.rightMargin: 14

        width: modules.implicitWidth + 20
        height: 30

        HoverHandler { id: statusPillHover }

        Behavior on width {
            NumberAnimation {
                duration: Motion.medium
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.standard
            }
        }

        Row {
            id: modules
            anchors.centerIn: parent
            spacing: 14

            Volume { id: volumeModule }
            Wifi { id: wifiModule }
            Bluetooth { id: bluetoothModule }
            Battery { id: batteryModule }
            Tray {}

            // The bell: opens the notification history; the count is gold
            // only when there is something to read.
            Row {
                spacing: 4

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰂚"
                    color: bar.notifications !== null && bar.notifications.count > 0
                        ? Theme.fg0 : Theme.fg1
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 14

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor

                        onClicked: {
                            if (bar.notifications !== null)
                                bar.notifications.openHistory();
                        }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: bar.notifications !== null && bar.notifications.count > 0
                    text: bar.notifications !== null ? bar.notifications.count : 0
                    color: Theme.gold
                    font.family: "Adwaita Sans"
                    font.pixelSize: 10
                }
            }

            Power {}
        }
    }
}
