// The bar. This is the root of the Quickshell config: Quickshell looks for
// ~/.config/quickshell/shell.qml and runs it.
//
// The surface is a transparent 34 px strip with three floating pills on it:
// workspaces on the left, the clock island in the centre, the status modules on
// the right. Nothing paints the strip itself, so the wallpaper shows between the
// pills; the pills are bg1 at 85% so it shows through them a little too.
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

    // The pills' fill. The palette stores opaque colours; the alpha here is
    // what makes them read as floating pills rather than three solid blocks.
    readonly property color pillColor: Qt.rgba(Theme.bg1.r, Theme.bg1.g, Theme.bg1.b, 0.85)
    readonly property color pillHover: Qt.rgba(Theme.bg2.r, Theme.bg2.g, Theme.bg2.b, 0.9)

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

    PanelWindow {
        anchors {
            top: true
            left: true
            right: true
        }

        implicitHeight: 38
        color: "transparent"

        // --- Left pill: the workspaces -------------------------------------
        // One circle per existing workspace, the focused one in gold. A plain
        // Repeater: Hyprland.workspaces is a live model, and the circle's size
        // never changes, so nothing needs a layout.
        Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 14

            width: workspaces.implicitWidth + 16
            height: 28
            radius: 14
            color: root.pillColor

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
                            ColorAnimation { duration: 160 }
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
        // The serif time is the one place the clock gets a voice; the date
        // stays small and sans so the hierarchy is time first, date second.
        Rectangle {
            id: island

            anchors.centerIn: parent
            width: clockRow.implicitWidth + 24
            height: 28
            radius: 14
            color: islandArea.containsMouse ? root.pillHover : root.pillColor

            Behavior on color {
                ColorAnimation { duration: 160 }
            }

            // The serif's digits are proportional; "88:88" measures the widest
            // case so the island keeps one width and does not breathe every
            // minute. tnum helps when the font has it, the fixed width covers
            // the case where it does not.
            TextMetrics {
                id: timeMetrics
                font.family: "Source Han Serif CN"
                font.pixelSize: 15
                font.bold: true
                font.features: ({ "tnum": 1 })
                text: "88:88"
            }

            Row {
                id: clockRow
                anchors.centerIn: parent
                spacing: 8

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.formatDateTime(clock.date, "hh:mm")
                    width: timeMetrics.width
                    horizontalAlignment: Text.AlignHCenter
                    color: Theme.fg0
                    font.family: "Source Han Serif CN"
                    font.pixelSize: 15
                    font.bold: true
                    // Tabular figures: the clock must not breathe every minute.
                    font.features: ({ "tnum": 1 })
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.formatDateTime(clock.date, "ddd d MMM")
                    color: Theme.fg1
                    font.family: "Adwaita Sans"
                    font.pixelSize: 11
                }
            }

            // Hover is the whole interaction until the control centre exists;
            // the MouseArea also claims the area for the click it will handle.
            MouseArea {
                id: islandArea
                anchors.fill: parent
                hoverEnabled: true
            }
        }

        // --- Right pill: the status modules --------------------------------
        Rectangle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: 14

            width: modules.implicitWidth + 20
            height: 28
            radius: 14
            color: root.pillColor

            Row {
                id: modules
                anchors.centerIn: parent
                spacing: 14

                Volume {}
                Wifi {}
                Bluetooth {}
                Battery {}
                Tray {}
                Power {}
            }
        }
    }
}
