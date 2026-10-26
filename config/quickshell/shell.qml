// The bar. This is the root of the Quickshell config: Quickshell looks for
// ~/.config/quickshell/shell.qml and runs it.
//
// The surface is a transparent 96 px window that reserves only the top 38 px
// (exclusiveZone): three floating pills sit in the top strip -- workspaces on
// the left, the clock island in the centre, the status modules on the right --
// and the extra height below them is where their drop shadows live. An input
// mask (Region over the three pills) lets clicks fall through the transparent
// rest, so a taller window changes nothing about hit-testing. The pills are
// Surface items (Tokens elevation); the wallpaper shows between them.
//
// The island is the seed of the dynamic island: it already reacts to hover, and
// the control centre will open from it. It is deliberately the only "chrome" in
// the middle, so the bar reads as three things instead of a row of widgets.
//
// QML is declarative: you describe a tree (a window containing a row containing
// one item per workspace) and bind properties to live data. Quickshell supplies
// the Wayland pieces (PanelWindow, the Hyprland module); QtQuick supplies the
// visuals (Rectangle, Text, Row).
//
// Colours come from Theme.qml, which scripts/gen-theme.py generates from
// config/hypr/theme.lua. There is no hex value in this file.

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

ShellRoot {
    id: root

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

    // The island opens the control centre centred under itself: the panel's
    // right margin is half of what is left of the screen once the panel is out.
    // The island is also the morph trigger, and it hides while the panel is
    // up (the panel IS the island, expanded) -- it comes back when the
    // window, and with it the return morph, is gone.
    function openControlCenter() {
        controlCenter.trigger = island;
        controlCenter.rightMargin = (bar.width - controlCenter.panelWidth) / 2;
        controlCenter.visible = true;
    }

    // The launcher is centred too; the panel width is fixed by Launcher.qml.
    function openLauncher() {
        launcher.rightMargin = (bar.width - launcher.panelWidth) / 2;
        launcher.open();
    }

    // The wallpaper picker is centred for the same reason.
    function openWallpaperPicker() {
        wallpaperPicker.rightMargin = (bar.width - wallpaperPicker.panelWidth) / 2;
        wallpaperPicker.open();
    }

    PanelWindow {
        id: bar

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
                            onClicked: root.focusWorkspace(modelData.id)
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

            // The control centre grows out of this surface; while its window
            // is up the island hides so there are never two copies (it comes
            // back only when the return morph has finished).
            opacity: controlCenter.visible && controlCenter.trigger === island ? 0 : 1

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
                onClicked: root.openControlCenter()
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
                        color: notifications.count > 0 ? Theme.fg0 : Theme.fg1
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 14

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: notifications.openHistory()
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: notifications.count > 0
                        text: notifications.count
                        color: Theme.gold
                        font.family: "Adwaita Sans"
                        font.pixelSize: 10
                    }
                }

                Power {}
            }
        }
    }

    // The control centre, as wide as the bar is narrow. The module cards close
    // it first, then open the module's own popup, so two backdrops never stack.
    ControlCenter {
        id: controlCenter

        onNetworkRequested: {
            controlCenter.visible = false;
            wifiModule.openPopup();
        }

        onBluetoothRequested: {
            controlCenter.visible = false;
            bluetoothModule.openPopup();
        }

        onBatteryRequested: {
            controlCenter.visible = false;
            batteryModule.openPopup();
        }

        onSessionRequested: {
            controlCenter.visible = false;
            Quickshell.execDetached(["sh", "-c", "$HOME/.config/hypr/scripts/session-menu"]);
        }
    }

    // The volume/brightness bubble at the bottom.
    Osd {
        id: osd
    }

    // The notification server, toasts and history. mako's service is disabled
    // while this owns org.freedesktop.Notifications.
    NotificationCenter {
        id: notifications
    }

    // The application launcher, opened by SUPER + Space through the IPC handler
    // below (config/hypr/scripts/launcher calls `qs ipc call launcher toggle`).
    Launcher {
        id: launcher
    }

    IpcHandler {
        target: "launcher"

        function toggle(): void {
            if (launcher.visible)
                launcher.close();
            else
                root.openLauncher();
        }

        function close(): void {
            launcher.close();
        }
    }

    // The wallpaper picker, opened by SUPER + W through the wallpaper script
    // (`qs ipc call wallpaper toggle`).
    WallpaperPicker {
        id: wallpaperPicker
    }

    IpcHandler {
        target: "wallpaper"

        function toggle(): void {
            if (wallpaperPicker.visible)
                wallpaperPicker.close();
            else
                root.openWallpaperPicker();
        }

        function close(): void {
            wallpaperPicker.close();
        }
    }

    // The control centre, so it can be opened from a script (screenshots,
    // future keybinds) without clicking the island.
    IpcHandler {
        target: "controlcenter"

        function toggle(): void {
            if (controlCenter.visible)
                controlCenter.close();
            else
                root.openControlCenter();
        }

        function close(): void {
            controlCenter.visible = false;
        }
    }
}
