// The system tray: one icon per application that asks for a permanent place in
// the bar (Discord, Steam, Syncthing, a mixer...). On Wayland this is the
// StatusNotifierItem protocol, and SystemTray is its host.
//
// SystemTray.items is an ObjectModel, so the Repeater follows it live; the
// count is read through .values because model[i] would not update reactively.
// Items come and go with their applications; the row's width collapses to zero
// when there is none, and the slot in the pill follows that width, so an empty
// tray leaves no gap. A binding on `values.length` is not reliable for the
// live case: an item inserted after the bar started did not re-trigger it.
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

    // The row is always visible; its width (and the slot that hosts it in the
    // pill) collapses to zero when there is no item, so an empty tray leaves
    // no gap. A binding on SystemTray.items.values.length is not reliable
    // here: an item inserted after the bar started did not re-trigger it.
    Repeater {
        id: repeater
        model: SystemTray.items

        delegate: Item {
            id: entry

            required property SystemTrayItem modelData

            width: 16
            height: 16

            // A bubble that grows out of the icon when it appears, then fades.
            // It is the "something just joined the bar" cue without moving the
            // pill: a short pop plus an expanding halo in the accent colour.
            Rectangle {
                id: bubble

                anchors.centerIn: parent
                width: 16
                height: 16
                radius: 8
                color: Qt.rgba(Theme.gold.r, Theme.gold.g, Theme.gold.b, 0.4)

                scale: 0.4
                opacity: 0

                Component.onCompleted: bubbleAnim.start()

                ParallelAnimation {
                    id: bubbleAnim

                    NumberAnimation {
                        target: bubble
                        property: "scale"
                        from: 0.4
                        to: 2.0
                        duration: Motion.slow
                        easing.type: Easing.OutCubic
                    }

                    NumberAnimation {
                        target: bubble
                        property: "opacity"
                        from: 0.55
                        to: 0
                        duration: Motion.slow
                        easing.type: Easing.OutCubic
                    }
                }
            }

            function openMenu() {
                // The icon's right edge, in window coordinates, which are screen
                // coordinates here because the bar spans the whole screen.
                const p = entry.mapToItem(null, 0, 0);
                menu.rightMargin = entry.Window.width - (p.x + entry.width);
                menu.open(entry.modelData.menu);
                menu.visible = true;
            }

            Item {
                id: iconWrap

                anchors.fill: parent

                scale: 0.4
                opacity: 0

                Component.onCompleted: pop.start()

                ParallelAnimation {
                    id: pop

                    NumberAnimation {
                        target: iconWrap
                        property: "scale"
                        from: 0.4
                        to: 1
                        duration: Motion.medium
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.5
                    }

                    NumberAnimation {
                        target: iconWrap
                        property: "opacity"
                        from: 0
                        to: 1
                        duration: Motion.base
                    }
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
