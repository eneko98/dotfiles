// One notification in the history: bg2 60% rounded interior, the app icon
// (image, appIcon or an initial), app name + relative time in fg1, the
// summary in fg0, the body clamped to two lines until clicked, and the
// actions as text buttons. A critical notification carries a red dot; an
// unread one carries a neon dot by the app name.
//
// Dismiss: the x button on hover, or a two-finger horizontal swipe -- the
// card follows the finger 1:1 and, on release, either leaves through the
// nearest side (fling, velocity-aware) or springs back (fling).
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
    property bool inserted: false      // false until Component.onCompleted
    property real offset: 0            // horizontal swipe offset in px

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
    height: dying ? 0 : (inserted ? implicitHeight : 0)
    clip: true
    opacity: dying ? 0 : (inserted ? 1 - Math.min(0.8, Math.abs(offset) / Math.max(1, width)) : 0)

    // Insertion: height and opacity grow together, opacity delayed 60 ms.
    Behavior on height {
        SequentialAnimation {
            NumberAnimation {
                duration: inserted ? Motion.base : Motion.fast
                easing.type: Easing.BezierSpline
                easing.bezierCurve: inserted ? Motion.decel : Motion.accel
            }
        }
    }
    Behavior on opacity {
        SequentialAnimation {
            PauseAnimation { duration: inserted ? 60 : 0 }
            NumberAnimation {
                duration: inserted ? Motion.base : Motion.fast
                easing.type: Easing.BezierSpline
                easing.bezierCurve: inserted ? Motion.decel : Motion.accel
            }
        }
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: root.tick++
    }

    Component.onCompleted: root.inserted = true

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

    NumberAnimation {
        id: swipeOutAnim
        target: root
        property: "offset"
        duration: Motion.fast
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Motion.accel
        onFinished: {
            root.dying = true;
            root.dismissed();
        }
    }

    NumberAnimation {
        id: swipeBackAnim
        target: root
        property: "offset"
        to: 0
        duration: Motion.medium
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Motion.standard
    }

    // The gesture is the shared SwipeTracker; vertical scroll is released
    // to the panel's Flickable.
    SwipeTracker {
        id: swipe
        anchors.fill: parent
        threshold: 0.35
        velocityThreshold: 0.6

        onMoved: function (offset) {
            root.offset = Math.max(-root.width, Math.min(root.width, offset));
        }

        onSwiped: function (direction, velocity) {
            const target = direction === "left" ? -root.width : root.width;
            const distance = Math.abs(target - root.offset);
            swipeOutAnim.to = target;
            swipeOutAnim.duration = Motion.release(distance, velocity,
                                                    Motion.flingSlope, 120, 240);
            swipeOutAnim.easing.bezierCurve = Motion.fling;
            swipeOutAnim.start();
        }

        onReleased: function (axis, velocity) {
            if (axis !== "x")
                return;
            const distance = Math.abs(root.offset);
            swipeBackAnim.duration = Motion.release(distance, velocity,
                                                     Motion.flingSlope, 160, 240);
            swipeBackAnim.easing.bezierCurve = Motion.fling;
            swipeBackAnim.start();
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
