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
// Submenus are a drill-down, not a side popup: clicking an entry that has
// children replaces the contents with them and adds a "back" row on top. One
// window, no hover tracking between windows, and every step is a click.
//
// The submenu needs a *stack of openers*, not one opener re-pointed at the
// entry: a QsMenuEntry belongs to the opener's model, so as soon as the model
// is replaced the entry is destroyed and `menu` becomes null. Keeping the
// parent opener alive keeps the entry alive, and the newest opener reads its
// children. That is also why closing destroys the whole stack.

import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: root

    WlrLayershell.namespace: Tokens.ns.menu

    // One QsMenuOpener per level, root first, current last.
    property var openers: []

    // Titles of the entries that were opened, for the back row.
    property var stack: []

    readonly property var currentOpener: openers.length > 0 ? openers[openers.length - 1] : null

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
    // Exclusive, not OnDemand: the menu must own the keyboard the moment it
    // appears, without waiting for a click inside it, so Escape works.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    color: "transparent"
    visible: false

    Component {
        id: openerComponent

        QsMenuOpener {}
    }

    function reset() {
        const old = root.openers;
        root.openers = [];
        root.stack = [];

        for (let i = 0; i < old.length; i++)
            old[i].destroy();
    }

    function open(handle) {
        root.reset();
        if (handle !== null && handle !== undefined)
            root.openers = [openerComponent.createObject(root, { menu: handle })];
    }

    function enter(entry) {
        if (entry === null || entry === undefined)
            return;

        root.stack = root.stack.concat([{ text: entry.text }]);
        root.openers = root.openers.concat([openerComponent.createObject(root, { menu: entry })]);
    }

    function back() {
        if (root.openers.length <= 1)
            return;

        const last = root.openers[root.openers.length - 1];
        root.openers = root.openers.slice(0, root.openers.length - 1);
        root.stack = root.stack.slice(0, root.stack.length - 1);
        last.destroy();
    }

    onVisibleChanged: if (!visible)
        reset()

    // The backdrop. Declared first, so the menu is drawn above it. All buttons,
    // not just the left one: a right or middle click outside should also
    // dismiss, and MouseArea only accepts the left button by default.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onClicked: root.visible = false
    }

    Rectangle {
        id: panel

        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 44
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
            acceptedButtons: Qt.AllButtons
        }

        Column {
            id: column
            anchors.fill: parent
            anchors.margins: 6
            spacing: 2

            // The way back, only while inside a submenu. It shows the entry
            // that was opened, which is also the submenu's title.
            Rectangle {
                id: backRow

                visible: root.stack.length > 0
                width: column.width
                height: 26
                radius: 4
                color: backHover.containsMouse ? Theme.bg2 : "transparent"

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 6
                    anchors.right: parent.right
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.stack.length > 0 ? "‹ " + root.stack[root.stack.length - 1].text : ""
                    color: Theme.gold
                    font.family: "Adwaita Sans"
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }

                MouseArea {
                    id: backHover

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.back()
                }
            }

            Repeater {
                model: root.currentOpener ? root.currentOpener.children : null

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
                            if (row.modelData.hasChildren) {
                                root.enter(row.modelData);
                            } else {
                                root.visible = false;
                                row.modelData.triggered();
                            }
                        }
                    }
                }
            }
        }
    }
}
