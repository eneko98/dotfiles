// The notification history: the header (title, do-not-disturb, Clear all)
// and the tracked notifications as cards, newest first. The list is live
// off the server's trackedNotifications; a dismiss removes the card. Empty:
// "No notifications" centred, no illustration. Clear all is deliberately
// NOT red: it is not destructive -- the same notifications can arrive again.
import QtQuick

Column {
    id: root

    property var server: null         // the NotificationCenter

    width: parent.width
    spacing: Tokens.space.s

    // Newest first: trackedNotifications is insertion-ordered.
    readonly property var cards: {
        if (!server)
            return [];
        const values = server.tracked.values.slice();
        values.reverse();
        return values;
    }

    function stampMs(id) {
        const stamp = server ? server.stamp(id) : 0;
        return stamp === undefined || stamp === null ? 0 : stamp;
    }

    // --- Header -----------------------------------------------------------
    Row {
        width: parent.width
        spacing: Tokens.space.s

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "Notifications"
            color: Theme.fg0
            font.family: "Adwaita Sans"
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }

        Pressable {
            width: dndLabel.implicitWidth + Tokens.space.s * 2
            height: 24

            onClicked: {
                if (root.server)
                    root.server.dnd = !root.server.dnd;
            }

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: root.server && root.server.dnd
                    ? Qt.rgba(Theme.teal.r, Theme.teal.g, Theme.teal.b, 0.18)
                    : "transparent"
                border.width: 1
                border.color: root.server && root.server.dnd ? "transparent" : Theme.bg2
            }

            Text {
                id: dndLabel
                anchors.centerIn: parent
                text: root.server && root.server.dnd ? "DND on" : "DND"
                color: root.server && root.server.dnd ? Theme.teal : Theme.fg1
                font.family: "Adwaita Sans"
                font.pixelSize: 11
            }
        }

        Pressable {
            anchors.verticalCenter: parent.verticalCenter
            width: clearLabel.implicitWidth + Tokens.space.s * 2
            height: 24
            visible: root.cards.length > 0

            onClicked: {
                if (root.server)
                    root.server.clearAll();
            }

            Text {
                id: clearLabel
                anchors.centerIn: parent
                text: "Clear all"
                color: parent.hovered ? Theme.fg0 : Theme.fg1
                font.family: "Adwaita Sans"
                font.pixelSize: 11
            }
        }
    }

    // --- The cards --------------------------------------------------------
    Repeater {
        model: root.cards

        delegate: NotificationItem {
            id: cardDelegate

            width: root.width
            server: root.server
            receivedAt: root.stampMs(modelData.id)

            onDismissed: {
                if (root.server)
                    root.server.dismiss(modelData);
            }
        }
    }

    Text {
        visible: root.cards.length === 0
        text: "No notifications"
        color: Theme.fg1
        font.family: "Adwaita Sans"
        font.pixelSize: 12
    }
}
