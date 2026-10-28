// One notification in the history: bg2 60% rounded interior, the app icon
// (image, appIcon or an initial), app name + relative time in fg1, the
// summary in fg0, the body clamped to two lines until clicked, and the
// actions as text buttons. A critical notification carries a red dot; an
// unread one carries a neon dot by the app name.
//
// Dismiss: the x button on hover, or a two-finger horizontal swipe -- the
// card follows the gesture with fading opacity, commits past 35% of its
// width or a 0.6px/ms flick, and collapses its height on the way out.
import Quickshell
import QtQuick
import QtQuick.Effects

Item {
    id: root

    property var server: null          // the NotificationCenter
    required property var modelData    // the Notification (set by the Repeater)
    property real receivedAt: 0        // ms, from the server's stamps

    // The card leaves in two steps: fade+collapse (this property) and only
    // then the actual dismiss, so the list does not reflow early.
    property bool dying: false
    property real offset: 0
    property string axis: ""
    property real _accX: 0
    property real _accY: 0
    property var _samples: []

    // Time refresher: relative labels update once a minute.
    property int tick: 0

    readonly property bool critical: modelData ? modelData.urgency === 2 : false
    readonly property bool unread: modelData && server ? !server.isRead(modelData) : false
    readonly property bool expandedBody: bodyLabel.maximumLineCount === Infinity
    readonly property bool hoverable: cardArea.containsMouse

    readonly property bool hasAvatar: modelData
        && modelData.image !== ""
        && !modelData.image.startsWith("image://icon/")
    readonly property string avatarSource: hasAvatar ? modelData.image : ""
    readonly property string iconSource: {
        if (!modelData)
            return "";
        if (!hasAvatar && modelData.image !== "")
            return modelData.image;
        if (modelData.appIcon !== "")
            return Quickshell.iconPath(modelData.appIcon, true);
        return "";
    }
    readonly property string appInitial: modelData && modelData.appName !== ""
        ? modelData.appName.charAt(0).toUpperCase() : "?"

    signal dismissed()

    implicitHeight: (modelData ? content.implicitHeight + Tokens.space.m * 2 : 0)

    width: parent.width
    height: dying ? 0 : implicitHeight
    clip: true
    opacity: dying ? 0 : 1 - Math.min(0.8, Math.abs(offset) / Math.max(1, width))

    Behavior on height {
        NumberAnimation {
            duration: Motion.base
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.accel
        }
    }
    Behavior on opacity {
        NumberAnimation {
            duration: Motion.base
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.accel
        }
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: root.tick++
    }

    function relative() {
        // touch `tick` so the binding re-evaluates once a minute
        root.tick;
        if (receivedAt <= 0)
            return "";
        const s = Math.max(1, Math.round((Date.now() - receivedAt) / 1000));
        if (s < 60) return s + " s";
        if (s < 3600) return Math.round(s / 60) + " min";
        if (s < 86400) return Math.round(s / 3600) + " h";
        if (s < 172800) return "Yesterday";
        return Math.round(s / 86400) + " d";
    }

    function release() {
        const now = Date.now();
        const recent = _samples.filter(s => now - s.t < 80);
        const v = recent.length > 1
            ? (recent[recent.length - 1].dx - recent[0].dx)
              / Math.max(1, recent[recent.length - 1].t - recent[0].t)
            : 0;
        _samples = [];
        axis = "";
        _accX = 0;
        _accY = 0;
        const far = Math.abs(offset) > width * 0.35;
        const fast = Math.abs(v) > 0.6 && Math.abs(offset) > 12;
        if (far || fast) {
            root.dying = true;
            root.dismissed();
        } else {
            offset = 0;
        }
    }

    Timer {
        id: idle
        interval: 90
        onTriggered: root.release()
    }

    // The gesture: WheelHandler never fires on this Wayland stack, so the
    // wheel is read from a MouseArea with no buttons (clicks pass through).
    MouseArea {
        anchors.fill: parent
        z: 1
        acceptedButtons: Qt.NoButton

        onWheel: function (event) {
            const dx = event.inverted ? event.pixelDelta.x : -event.pixelDelta.x;
            const dy = event.pixelDelta.y;
            if (root.axis === "") {
                root._accX += Math.abs(dx);
                root._accY += Math.abs(dy);
                if (root._accX + root._accY < 8) {
                    idle.restart();
                    return;
                }
                root.axis = root._accX >= root._accY ? "x" : "y";
            }
            if (root.axis === "y") {
                event.accepted = false;
                idle.restart();
                return;
            }
            root.offset = Math.max(-root.width, Math.min(root.width, root.offset + dx));
            root._samples = root._samples.concat([{ t: Date.now(), dx: root.offset }]).slice(-8);
            idle.restart();
        }
    }

    // --- The card ---------------------------------------------------------
    Rectangle {
        id: card
        anchors.fill: parent
        radius: Tokens.radius.card
        color: Qt.rgba(Theme.bg2.r, Theme.bg2.g, Theme.bg2.b, 0.60)
        // The swipe offset: on the card, not the root -- a Column manages
        // its children's x, so the root's x would be fought.
        x: root.offset

        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            width: 3
            height: parent.height
            radius: 1.5
            visible: root.critical
            color: Theme.red
        }

        Column {
            id: content

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Tokens.space.m
            spacing: Tokens.space.xs

            Row {
                width: parent.width
                spacing: Tokens.space.s

                // Icon: avatar, image, appIcon, or the app's initial.
                Item {
                    width: root.hasAvatar ? 24 : 20
                    height: root.hasAvatar ? 24 : 20
                    anchors.verticalCenter: parent.verticalCenter

                    Avatar {
                        anchors.fill: parent
                        visible: root.hasAvatar
                        size: 24
                        source: root.avatarSource
                    }

                    Image {
                        anchors.fill: parent
                        visible: !root.hasAvatar && root.iconSource !== ""
                        source: root.iconSource
                        sourceSize.width: 20
                        sourceSize.height: 20
                        fillMode: Image.PreserveAspectFit
                    }

                    Rectangle {
                        anchors.fill: parent
                        visible: !root.hasAvatar && root.iconSource === ""
                        radius: width / 2
                        color: Theme.bg2

                        Text {
                            anchors.centerIn: parent
                            text: root.appInitial
                            color: Theme.fg1
                            font.family: "Adwaita Sans"
                            font.pixelSize: 10
                            font.bold: true
                        }
                    }
                }

                // Unread: neon dot before the name.
                Rectangle {
                    visible: root.unread
                    anchors.verticalCenter: parent.verticalCenter
                    width: 6
                    height: 6
                    radius: 3
                    color: Theme.teal
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.modelData ? root.modelData.appName : ""
                    color: Theme.fg1
                    font.family: "Adwaita Sans"
                    font.pixelSize: 12
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.receivedAt > 0 ? root.relative() : ""
                    color: Theme.fg1
                    font.family: "Adwaita Sans"
                    font.pixelSize: 11
                }
            }

            Text {
                width: parent.width
                text: root.modelData ? root.modelData.summary : ""
                color: Theme.fg0
                font.family: "Adwaita Sans"
                font.pixelSize: 13
                elide: Text.ElideRight
            }

            Text {
                id: bodyLabel

                width: parent.width
                visible: root.modelData && root.modelData.body !== ""
                text: root.modelData ? root.modelData.body : ""
                color: Theme.fg1
                font.family: "Adwaita Sans"
                font.pixelSize: 12
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }

            Row {
                spacing: Tokens.space.s

                Repeater {
                    model: root.modelData && root.modelData.actions
                        ? root.modelData.actions : []

                    delegate: Pressable {
                        required property var modelData

                        width: actionLabel.implicitWidth + Tokens.space.s * 2
                        height: 28

                        onClicked: modelData.invoke()

                        Text {
                            id: actionLabel
                            anchors.centerIn: parent
                            text: modelData.text
                            color: parent.hovered ? Theme.fg0 : Theme.fg1
                            font.family: "Adwaita Sans"
                            font.pixelSize: 12
                        }
                    }
                }
            }
        }

        // The x: hover only (and keyboard focus).
        Pressable {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Tokens.space.s
            width: 24
            height: 24
            visible: root.hoverable

            onClicked: {
                root.dying = true;
                root.dismissed();
            }

            Text {
                anchors.centerIn: parent
                text: "✕"
                color: parent.hovered ? Theme.fg0 : Theme.fg2
                font.family: "Adwaita Sans"
                font.pixelSize: 12
            }
        }

        // Click: expand/collapse the body. hoverEnabled feeds the x button.
        MouseArea {
            id: cardArea
            anchors.fill: parent
            z: -1
            hoverEnabled: true
            cursorShape: Qt.ArrowCursor
            onClicked: bodyLabel.maximumLineCount
                = bodyLabel.maximumLineCount === Infinity ? 2 : Infinity
        }
    }
}
