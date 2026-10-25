// The system tray: one icon per application that asks for a permanent place in
// the bar (Discord, Steam, Syncthing, a mixer...). On Wayland this is the
// StatusNotifierItem protocol, and SystemTray is its host.
//
// SystemTray.items is an ObjectModel, so the Repeater follows it live; the
// count is read through .values because model[i] would not update reactively.
// Items come and go with their applications, so the whole row hides when there
// is none: an empty tray leaves no gap.
//
// Clicks follow the de-facto convention: left runs the primary action (or opens
// the menu when that is all the item offers), right opens the menu, middle runs
// the secondary action.

import Quickshell
import Quickshell.Services.SystemTray
import QtQuick

Row {
    id: root

    spacing: 6

    visible: SystemTray.items.values.length > 0

    Repeater {
        model: SystemTray.items

        delegate: Item {
            id: entry

            required property SystemTrayItem modelData

            width: 16
            height: 16

            function openMenu() {
                // The icon's right edge, in window coordinates, which are screen
                // coordinates here because the bar spans the whole screen.
                const p = entry.mapToItem(null, 0, 0);
                menu.rightMargin = entry.Window.width - (p.x + entry.width);
                menu.open(entry.modelData.menu);
                menu.visible = true;
            }

            Image {
                anchors.fill: parent
                source: entry.modelData.icon
                sourceSize.width: 16
                sourceSize.height: 16
                fillMode: Image.PreserveAspectFit
                smooth: true
                opacity: mouse.containsMouse ? 1.0 : 0.85
            }

            Menu {
                id: menu
            }

            MouseArea {
                id: mouse

                anchors.fill: parent
                hoverEnabled: true
                // MouseArea only accepts the left button by default, so a
                // right click would never reach onClicked.
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                cursorShape: Qt.PointingHandCursor

                onClicked: function(mouse) {
                    if (mouse.button === Qt.LeftButton) {
                        if (entry.modelData.onlyMenu)
                            entry.openMenu();
                        else
                            entry.modelData.activate();
                    } else if (mouse.button === Qt.RightButton) {
                        if (entry.modelData.hasMenu)
                            entry.openMenu();
                    } else if (mouse.button === Qt.MiddleButton) {
                        entry.modelData.secondaryActivate();
                    }
                }
            }
        }
    }
}
