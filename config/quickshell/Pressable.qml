// Shared hover / press / focus / scroll behaviour: the base of everything
// clickable in panels and pills. Subclass it (or put content inside it) and
// bind to `hovered` / `pressed`; handle `clicked` / `secondaryClicked` /
// `middleClicked` / `scrolled`.
//
// The press feedback is a 0.97 scale (Motion.press). The focus ring follows
// Nav: only drawn when focus arrived by keyboard, cleared by any mouse press.
//
// Handler note: signal handlers that need the event must use the
// `function (m) { }` form -- arrow functions do not receive it (the bug that
// made the tray look dead).
import QtQuick

Item {
    id: root

    signal clicked()
    signal secondaryClicked()
    signal middleClicked()
    signal scrolled(real dy)

    readonly property bool hovered: mouse.containsMouse
    readonly property bool pressed: mouse.pressed
    readonly property bool focusRing: root.activeFocus && Nav.keyboard
    property real pressScale: 0.97

    activeFocusOnTab: enabled
    scale: root.pressed ? pressScale : 1
    Behavior on scale {
        NumberAnimation {
            duration: Motion.press
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.decel
        }
    }

    Keys.onPressed: function (event) {
        if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab)
            Nav.tab();
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            root.clicked();
            event.accepted = true;
            return;
        }
        event.accepted = false;
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        // All buttons: the default is left-only, which is what made right
        // clicks unreachable in the tray menu.
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onPressed: Nav.mouse()
        onClicked: function (m) {
            if (m.button === Qt.RightButton) root.secondaryClicked();
            else if (m.button === Qt.MiddleButton) root.middleClicked();
            else root.clicked();
        }
        onWheel: function (w) { root.scrolled(w.angleDelta.y); }
    }

    // Focus ring: 2 px accent, outside the bounds.
    Rectangle {
        anchors.fill: parent
        anchors.margins: -2
        radius: height / 2
        color: "transparent"
        border.width: 2
        border.color: Theme.gold
        visible: root.focusRing
    }
}
