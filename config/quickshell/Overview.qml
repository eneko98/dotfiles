// The workspace carousel: a Cover Flow of the existing workspaces, one card
// per workspace with a preview of its active window. The card in the middle
// is the current workspace; the others lean back with a Y rotation.
//
// Opened from the three-finger vertical gesture or SUPER+Tab, it closes with
// Escape, a click outside, or by selecting a card. A card previews the
// workspace's activated toplevel (or its first one) through ScreencopyView,
// captured once when the overview opens: live video for every window would be
// too much for a peek.
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick

Popup {
    id: root

    panelWidth: 1100
    panelExtra: 0.3
    centerVertically: true

    // Special workspaces have a negative id and their own namespace; they are
    // not part of the carousel.
    readonly property var workspaces: Hyprland.workspaces.values.filter(w => w.id >= 0)
    readonly property int count: workspaces.length

    property int current: 0

    // Live two-finger drag offset, in pixels: the cards follow the fingers
    // while SwipeTracker reports movement and snap on release.
    property real drag: 0
    property bool dragging: false

    function syncCurrent() {
        for (let i = 0; i < workspaces.length; i++) {
            if (workspaces[i].focused) {
                current = i;
                return;
            }
        }
        current = 0;
    }

    function step(delta) {
        if (count === 0)
            return;
        current = Math.max(0, Math.min(count - 1, current + delta));
    }

    function select() {
        if (current >= 0 && current < count) {
            workspaces[current].activate();
            close();
        }
    }

    // The base Popup already owns onVisibleChanged (it arms the morph and
    // opens Panels), so this listens instead of overriding it. callLater
    // gives the base panel focus a chance to settle before the carousel takes
    // the arrow keys.
    Connections {
        target: root

        function onVisibleChanged() {
            if (root.visible) {
                root.syncCurrent();
                Qt.callLater(function () { carousel.forceActiveFocus(); });
            }
        }
    }

    Item {
        id: carousel

        width: parent.width
        height: 310

        focus: true

        Keys.onLeftPressed: root.step(-1)
        Keys.onRightPressed: root.step(1)
        Keys.onReturnPressed: root.select()
        Keys.onEnterPressed: root.select()
        Keys.onEscapePressed: root.close()

        Text {
            id: title

            text: "Workspaces"
            color: Theme.fg0
            font.family: "Adwaita Sans"
            font.pixelSize: 15
            font.bold: true
            anchors.left: parent.left
            anchors.top: parent.top
        }

        Text {
            text: "← →   ·   Enter   ·   Esc"
            color: Theme.fg2
            font.family: "Adwaita Sans"
            font.pixelSize: 11
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: 3
        }

        Item {
            id: cards

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: 40
            height: 260
            clip: false

            Repeater {
                model: root.workspaces

                delegate: Item {
                    id: cardItem

                    required property HyprlandWorkspace modelData
                    required property int index

                    readonly property int distance: index - root.current
                    readonly property var preview: {
                        const list = modelData.toplevels.values;
                        for (let i = 0; i < list.length; i++) {
                            if (list[i].activated)
                                return list[i];
                        }
                        return list.length > 0 ? list[0] : null;
                    }

                    width: 420
                    height: 260
                    x: cards.width / 2 - width / 2 + distance * 300 + root.drag
                    scale: 1 - Math.min(2, Math.abs(distance)) * 0.12
                    opacity: 1 - Math.min(2, Math.abs(distance)) * 0.2
                    z: 20 - Math.abs(distance)

                    transform: Rotation {
                        origin.x: cardItem.width / 2
                        origin.y: cardItem.height / 2
                        axis { x: 0; y: 1; z: 0 }
                        angle: Math.max(-28, Math.min(28, -distance * 18))

                        Behavior on angle {
                            NumberAnimation {
                                duration: Motion.medium
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Motion.decel
                            }
                        }
                    }

                    Behavior on x {
                        enabled: !root.dragging

                        NumberAnimation {
                            duration: Motion.medium
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Motion.decel
                        }
                    }

                    Behavior on scale {
                        NumberAnimation {
                            duration: Motion.medium
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Motion.decel
                        }
                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Motion.medium
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Motion.decel
                        }
                    }

                    Surface {
                        id: card

                        anchors.fill: parent
                        level: 2
                        radius: 14
                        borderColor: cardItem.distance === 0
                            ? Theme.gold
                            : Qt.rgba(Theme.fg0.r, Theme.fg0.g, Theme.fg0.b, 0.12)
                    }

                    Item {
                        anchors.fill: parent
                        anchors.margins: 1
                        clip: true

                        ScreencopyView {
                            anchors.fill: parent
                            captureSource: root.visible && cardItem.preview
                                ? cardItem.preview.wayland : null
                            live: false
                            constraintSize: Qt.size(640, 360)
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: cardItem.preview === null
                            text: cardItem.modelData.name
                            color: Theme.fg2
                            font.family: "Adwaita Sans"
                            font.pixelSize: 56
                            font.bold: true
                        }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 72

                            gradient: Gradient {
                                GradientStop {
                                    position: 0.0
                                    color: Qt.rgba(Theme.bg0.r, Theme.bg0.g, Theme.bg0.b, 0.0)
                                }
                                GradientStop {
                                    position: 1.0
                                    color: Qt.rgba(Theme.bg0.r, Theme.bg0.g, Theme.bg0.b, 0.92)
                                }
                            }
                        }

                        Column {
                            anchors.left: parent.left
                            anchors.leftMargin: 14
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 12
                            spacing: 2

                            Row {
                                spacing: 6

                                Rectangle {
                                    width: 6
                                    height: 6
                                    radius: 3
                                    color: Theme.gold
                                    visible: cardItem.modelData.focused
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: "Workspace " + cardItem.modelData.name
                                    color: Theme.fg0
                                    font.family: "Adwaita Sans"
                                    font.pixelSize: 14
                                    font.bold: true
                                }
                            }

                            Text {
                                text: cardItem.modelData.toplevels.values.length === 1
                                    ? "1 window"
                                    : cardItem.modelData.toplevels.values.length + " windows"
                                color: Theme.fg1
                                font.family: "Adwaita Sans"
                                font.pixelSize: 11
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor

                        onClicked: {
                            root.current = cardItem.index;
                            root.select();
                        }
                    }
                }
            }
        }

        // Two fingers and the wheel move the carousel; accepting no buttons
        // leaves the card clicks to the cards underneath.
        SwipeTracker {
            anchors.fill: parent

            // The shared tracker defaults to a full-width workspace swipe;
            // one card is much shorter, so the threshold follows the gesture.
            threshold: 0.06
            velocityThreshold: 0.2

            onMoved: function (offset) {
                root.dragging = true;
                root.drag = offset;
            }

            onSwiped: function (direction) {
                root.dragging = false;
                root.drag = 0;
                root.step(direction === "left" ? 1 : -1);
            }

            onReleased: function (axis) {
                if (axis === "x") {
                    root.dragging = false;
                    root.drag = 0;
                }
            }

            onWheeled: function (direction) {
                root.step(direction === "up" ? 1 : -1);
            }
        }
    }
}
