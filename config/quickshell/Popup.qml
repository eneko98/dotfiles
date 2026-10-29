// The modal shell behind every bar panel: a full-screen transparent layer
// surface on the overlay layer -- the StageWindow of the redesign. It holds
// the dim (bg0 at 18%), the click-outside-to-close backdrop, and one
// MorphPanel: the content surface that grows out of the trigger that opened
// it (an island, a pill) and shrinks back into it on close.
//
// Why a full-screen surface: see Menu.qml. A popup cannot attach to a
// layer-shell bar (Qt's own popups and PopupWindow both need an xdg_toplevel),
// and a click anywhere outside has to land somewhere, so the transparent
// backdrop takes it and closes the popup. Exclusive keyboard focus is what
// makes Escape work; it is held only while the popup is visible.
//
// Opening: the caller sets `visible = true` (as before). With a `trigger`
// set, the panel morphs out of it and close() animates the return before
// hiding; without one, the panel fades in place and close() is instant.
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

    // Extra fill alpha for panels that should read more solid than the
    // default translucent stage (the workspace overview). 0 is the norm.
    property real panelExtra: 0

    // Panels that hang under the bar (the module popups, the control centre)
    // leave this false; a launcher in the middle of the screen sets it.
    property bool centerVertically: false

    // The item the panel grows out of, in another window (the bar). Null
    // means "fade in place".
    property Item trigger: null

    // Children of a Popup land in the panel's column.
    default property alias content: column.data

    // Children that must cover the panel instead of flowing in it (a
    // SubPage pushed over the sections) go here: they land on a layer
    // above the column, filling the MorphPanel.
    property alias overlay: overlayLayer.data

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // A popup is not a bar: it must not reserve screen space.
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: Tokens.ns.stage
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    color: "transparent"
    visible: false

    // The panel's final geometry. The height follows the content: the
    // column's implicit height plus the MorphPanel's padding on both sides.
    readonly property real panelHeight: column.implicitHeight + Tokens.space.l * 2

    readonly property rect finalRect: Qt.rect(
        width - rightMargin - panelWidth,
        centerVertically ? Math.round((height - panelHeight) / 2) : topMargin,
        panelWidth,
        panelHeight)

    // The trigger's rect in window coordinates: the bar is anchored at (0,0)
    // and this window is full-screen, so both live in the same space.
    readonly property rect fromRect: trigger !== null
        ? trigger.mapToItem(null, 0, 0, trigger.width, trigger.height)
        : finalRect

    onVisibleChanged: {
        // Opening arms the morph (or the in-place fade). Closing a trigger
        // panel goes through close(); a direct visible=false still resets
        // the state (the closeAnim runs hidden, harmless).
        panel.open = visible;
        if (visible) {
            panel.forceActiveFocus();
            Panels.open(root);
        } else {
            Panels.closed(root);
        }
    }

    // Close through the morph when there is a trigger; instant otherwise.
    // Split from close() so a panel subclass can intercept Escape (the
    // System panel goes back from its processes page first) and still reach
    // the base behaviour.
    function closePanel() {
        if (trigger !== null)
            panel.open = false;
        else
            visible = false;
    }

    function close() {
        root.closePanel();
    }

    // The dim behind the panel. It fades in with the opening; the close is
    // the window hiding (with a trigger, only after the morph is back).
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(Theme.bg0.r, Theme.bg0.g, Theme.bg0.b, 0.18)
        opacity: root.visible ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: root.visible ? Motion.base : Motion.fast
                easing.type: Easing.BezierSpline
                easing.bezierCurve: root.visible ? Motion.standard : Motion.accel
            }
        }
    }

    // The backdrop: any click outside the panel closes. All buttons, not just
    // the left one: MouseArea defaults to Qt.LeftButton.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onClicked: root.close()
    }

    // Swallow clicks that land on the panel's area but miss its controls, so
    // they do not reach the backdrop. Follows the morph's live geometry.
    MouseArea {
        x: panel.x
        y: panel.y
        width: panel.width
        height: panel.height
        acceptedButtons: Qt.AllButtons
    }

    MorphPanel {
        id: panel

        from: root.fromRect
        to: root.finalRect
        fromRadius: root.trigger !== null ? root.trigger.height / 2 : -1
        extra: root.panelExtra
        open: false

        focus: true
        Keys.onEscapePressed: root.close()

        onClosed: root.visible = false

        Column {
            id: column
            width: panel.to.width - Tokens.space.l * 2
            spacing: 8
        }

        // Above the content: a layer for things that cover the panel (a
        // SubPage pushed over the sections). Children arrive through the
        // Popup's `overlay` alias.
        Item {
            id: overlayLayer
            anchors.fill: parent
        }
    }
}
