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
    readonly property real cardWidth: 420

    property int current: 0
    // Continuous carousel position in cards (0 = current workspace centred).
    // Keyboard/step changes animate this; the drag sets it 1:1 with the finger.
    property real p: 0
    property real dragStartP: 0
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
        const base = snap.running ? snap.to : current;
        const target = Math.max(0, Math.min(count - 1, base + delta));
        if (target === base)
            return;
        snap.stop();
        snap.duration = Motion.fast;
        snap.easing.bezierCurve = Motion.standard;
        snap.to = target;
        snap.start();
    }

    function select() {
        if (current >= 0 && current < count) {
            workspaces[current].activate();
            close();
        }
    }

    NumberAnimation {
        id: snap
        target: root
        property: "p"
        duration: Motion.medium
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Motion.decel
        onFinished: root.current = Math.round(root.p)
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
                root.p = root.current;
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

                    readonly property real distance: index - root.p
                    readonly property var preview: {
                        const list = modelData.toplevels.values;
                        for (let i = 0; i < list.length; i++) {
                            if (list[i].activated)
                                return list[i];
                        }
                        return list.length > 0 ? list[0] : null;
                    }

                    width: root.cardWidth
                    height: 260
                    x: {
                        const center = cards.width / 2 - root.cardWidth / 2;
                        const d = index - root.p;
                        let offset;
                        if (Math.abs(d) <= 1) {
                            offset = d * 0.55 * root.cardWidth;
                        } else {
                            offset = Math.sign(d) * (0.55 * root.cardWidth
                                + (Math.abs(d) - 1) * 0.25 * root.cardWidth);
                        }
                        return center + offset;
                    }
                    scale: {
                        const d = Math.abs(index - root.p);
                        return 1 - 0.16 * Math.min(d, 1)
                                 - 0.06 * Math.max(0, Math.min(d - 1, 1));
                    }
                    opacity: {
                        const d = Math.abs(index - root.p);
                        return 1 - 0.3 * Math.min(d, 2) / 2;
                    }
                    z: -Math.abs(index - root.p)

                    transform: Rotation {
                        origin.x: cardItem.width / 2
                        origin.y: cardItem.height / 2
                        axis { x: 0; y: 1; z: 0 }
                        angle: {
                            const d = index - root.p;
                            return -Math.sign(d) * 30 * Math.min(Math.abs(d), 1);
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
                            root.p = cardItem.index;
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
                if (!root.dragging) {
                    root.dragStartP = root.p;
                    root.dragging = true;
                }
                root.p = root.dragStartP - offset / root.cardWidth;
            }

            onSwiped: function (direction, velocity) {
                root.dragging = false;
                const target = Math.max(0, Math.min(root.count - 1,
                    root.current + (direction === "left" ? 1 : -1)));
                const distance = Math.abs(target - root.p) * root.cardWidth;
                snap.duration = Motion.release(distance, velocity,
                                                Motion.snapSlope, 160, 320);
                snap.easing.bezierCurve = Motion.snap;
                snap.to = target;
                snap.start();
            }

            onReleased: function (axis, velocity) {
                if (axis === "x") {
                    root.dragging = false;
                    const target = Math.max(0, Math.min(root.count - 1,
                                                        Math.round(root.p)));
                    const distance = Math.abs(target - root.p) * root.cardWidth;
                    snap.duration = Motion.release(distance, velocity,
                                                    Motion.snapSlope, 160, 320);
                    snap.easing.bezierCurve = Motion.snap;
                    snap.to = target;
                    snap.start();
                }
            }

            onWheeled: function (direction) {
                root.step(direction === "up" ? 1 : -1);
            }
        }
    }
}
