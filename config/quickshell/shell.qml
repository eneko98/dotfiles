// The bar. This is the root of the Quickshell config: Quickshell looks for
// ~/.config/quickshell/shell.qml and runs it.
//
// QML is declarative: you describe a tree (a window containing a row containing
// one item per workspace) and bind properties to live data. Quickshell supplies
// the Wayland pieces (PanelWindow, the Hyprland module); QtQuick supplies the
// visuals (Rectangle, Text, Row).
//
// Colours come from Theme.qml, which scripts/gen-theme.py generates from
// config/hypr/theme.lua. There is no hex value in this file.
//
// First step, left to right: the workspaces only. The clock and the right-hand
// modules arrive one at a time.

import Quickshell
import Quickshell.Hyprland
import QtQuick

ShellRoot {
    PanelWindow {
        anchors {
            top: true
            left: true
            right: true
        }

        implicitHeight: 34
        // Transparent surface, so only the components paint and the wallpaper
        // shows through the rest. "transparent" is a QML colour keyword, not a
        // palette value, so the no-hex rule still holds.
        color: "transparent"

        // The left group. A plain Row, not a layout: the items have fixed sizes
        // and no need to share space.
        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 14
            spacing: 6

            // One rounded box per workspace. Hyprland.workspaces is a live list
            // that updates as workspaces are created, destroyed or focused.
            Repeater {
                model: Hyprland.workspaces

                delegate: Rectangle {
                    required property var modelData

                    width: 28
                    height: 24
                    radius: 6
                    color: modelData.focused ? Theme.gold : Theme.bg2

                    Text {
                        anchors.centerIn: parent
                        text: modelData.id
                        color: modelData.focused ? Theme.bg0 : Theme.fg1
                        font.family: "Adwaita Sans"
                        font.pixelSize: 12
                        font.bold: modelData.focused
                    }
                }
            }
        }
    }
}
