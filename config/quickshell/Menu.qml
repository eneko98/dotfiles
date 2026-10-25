// A tray item's menu, drawn in QML instead of as a platform menu.
//
// Three dead ends came first, all worth remembering:
//   * QsMenuAnchor asks Qt for a native menu, which is impossible when the
//     parent is a wlr-layer-shell surface ("popup is not an xdg_popup").
//   * PopupWindow is a proxy popup and fails for the same reason: it needs an
//     xdg_toplevel to attach to, and the bar is not one.
//   * HyprlandFocusGrab, the obvious dismissal tool, stops the surface from
//     getting keyboard focus at all, so Escape never arrives.
// What works is one layer surface on the overlay layer, full-screen and
// transparent: the menu is drawn in the corner, and a click anywhere else lands
// on a backdrop MouseArea that closes it. A menu is modal anyway, so swallowing
// that click is the correct behaviour, and it is also the only way to see it.
//
// Exclusive keyboard focus is what makes Escape work; the full-screen surface
// means the keyboard is held only while the menu is open.
//
// QsMenuOpener turns the item's DBusMenu into a list of QsMenuEntry objects,
// which are drawn with the palette here.
//
// Flat on purpose: an entry with children shows the arrow but does not open a
// submenu yet. No tray app in use has one; when one appears, this is where the
// nested menu goes.

import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: root

    // The QsMenuHandle to display (a tray item, or a menu entry).
    property var menu: null

    // Distance from the screen's right edge to the menu's right edge: the tray
    // icon's right edge, so the menu hangs under it. Set when it opens.
    property real rightMargin: 14

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // A menu is not a bar: it must not reserve screen space.
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    color: "transparent"
    visible: false

    // The backdrop. Declared first, so the menu is drawn above it.
    MouseArea {
        anchors.fill: parent
        onClicked: root.visible = false
    }

    Rectangle {
        id: panel

        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 40
        anchors.rightMargin: root.rightMargin

        implicitWidth: 220
        implicitHeight: column.implicitHeight + 12
        radius: 8
        color: Theme.bg1
        border.width: 1
        border.color: Theme.gold

        focus: true
        Keys.onEscapePressed: root.visible = false

        Connections {
            target: root
            function onVisibleChanged() {
                if (root.visible)
                    panel.forceActiveFocus();
            }
        }

        // Swallow clicks on the menu's padding, so only clicks outside it
        // reach the backdrop and dismiss.
        MouseArea {
            anchors.fill: parent
        }

        QsMenuOpener {
            id: opener
            menu: root.menu
        }

        Column {
            id: column
            anchors.fill: parent
            anchors.margins: 6
            spacing: 2

            Repeater {
                model: opener.children

                delegate: Rectangle {
                    id: row

                    required property QsMenuEntry modelData

                    width: column.width
                    height: row.modelData.isSeparator ? 7 : 26
                    radius: 4
                    color: !row.modelData.isSeparator && row.modelData.enabled && hover.containsMouse ? Theme.bg2 : "transparent"

                    Rectangle {
                        visible: row.modelData.isSeparator
                        anchors.centerIn: parent
                        width: parent.width - 12
                        height: 1
                        color: Theme.bg2
                    }

                    // One 16 px slot on the left: a tick for checkboxes and
                    // radio buttons, the item's icon otherwise.
                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !row.modelData.isSeparator && row.modelData.buttonType !== QsMenuButtonType.None
                        text: row.modelData.checkState === Qt.Checked ? "✓" : ""
                        color: Theme.gold
                        font.family: "Adwaita Sans"
                        font.pixelSize: 12
                        width: 14
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Image {
                        anchors.left: parent.left
                        anchors.leftMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !row.modelData.isSeparator && row.modelData.icon !== ""
                        width: 16
                        height: 16
                        source: row.modelData.icon
                        sourceSize.width: 16
                        sourceSize.height: 16
                        fillMode: Image.PreserveAspectFit
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 26
                        anchors.right: parent.right
                        anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !row.modelData.isSeparator
                        text: row.modelData.text
                        color: row.modelData.enabled ? Theme.fg0 : Theme.fg2
                        font.family: "Adwaita Sans"
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !row.modelData.isSeparator && row.modelData.hasChildren
                        text: "›"
                        color: Theme.fg2
                        font.family: "Adwaita Sans"
                        font.pixelSize: 14
                    }

                    MouseArea {
                        id: hover

                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: !row.modelData.isSeparator && row.modelData.enabled
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

                        onClicked: {
                            root.visible = false;
                            row.modelData.triggered();
                        }
                    }
                }
            }
        }
    }
}
