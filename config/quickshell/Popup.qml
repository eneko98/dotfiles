// The modal shell behind every bar popup: a full-screen transparent layer
// surface on the overlay layer, with the panel drawn in the top-right corner
// under the module that opened it.
//
// Why a full-screen surface: see Menu.qml. A popup cannot attach to a
// layer-shell bar (Qt's own popups and PopupWindow both need an xdg_toplevel),
// and a click anywhere outside has to land somewhere, so the transparent
// backdrop takes it and closes the popup. Exclusive keyboard focus is what makes
// Escape work; it is held only while the popup is visible.
//
// Instances declare their content as children, which the default alias routes
// into the column inside the panel. `rightMargin` is the distance from the
// screen's right edge to the panel's right edge: the caller sets it to the
// right edge of the module that opened it, so the panel hangs under it.

import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: root

    // Distance from the screen's right edge to the panel's right edge. Set by
    // the module that opens the popup.
    property real rightMargin: 14

    // The panel's top, just below the 38 px bar.
    property real topMargin: 44

    property real panelWidth: 240

    // Panels that hang under the bar (the module popups, the control centre)
    // leave this false; a launcher in the middle of the screen sets it.
    property bool centerVertically: false

    // Children of a Popup land in the panel's column.
    default property alias content: column.data

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // A popup is not a bar: it must not reserve screen space.
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    color: "transparent"
    visible: false

    // The backdrop. Declared first, so the panel is drawn above it. All
    // buttons, not just the left one: MouseArea defaults to Qt.LeftButton.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onClicked: root.visible = false
    }

    Rectangle {
        id: panel

        // y instead of a top anchor: the centred case needs to follow the
        // panel's own height as the list grows or shrinks.
        y: root.centerVertically ? Math.round((parent.height - height) / 2) : root.topMargin
        anchors.right: parent.right
        anchors.rightMargin: root.rightMargin

        implicitWidth: root.panelWidth
        implicitHeight: column.implicitHeight + 12
        radius: 8
        color: Theme.bg1
        border.width: 1
        border.color: Theme.gold

        // The window maps and the panel fades/scales in from its top edge. The
        // close is instant: the window is hidden the moment `visible` goes false.
        opacity: root.visible ? 1 : 0
        scale: root.visible ? 1 : 0.96
        transformOrigin: root.centerVertically ? Item.Center : Item.Top

        Behavior on opacity {
            NumberAnimation {
                duration: Motion.fade
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.decel
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: Motion.base
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.decel
            }
        }

        focus: true
        Keys.onEscapePressed: root.visible = false

        Connections {
            target: root
            function onVisibleChanged() {
                if (root.visible)
                    panel.forceActiveFocus();
            }
        }

        // Swallow clicks on the panel's padding, so only clicks outside it
        // reach the backdrop and dismiss.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
        }

        Column {
            id: column
            anchors.fill: parent
            anchors.margins: 6
            spacing: 8
        }
    }
}
