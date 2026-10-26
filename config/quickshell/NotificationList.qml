// The notification history: the header (title, unread count, DND, Clear all)
// and the tracked notifications grouped by app. Criticals float to the top;
// a group with more than one item shows its latest and expands on click.
// The list is live off the server's trackedNotifications; a dismiss removes
// the card. Clear all is deliberately NOT red: it is not destructive.
import Quickshell
import QtQuick

Column {
    id: root

    property var server: null         // the NotificationCenter
    property var expandedGroups: ({})

    width: parent.width
    spacing: Tokens.space.s

    function toggleGroup(appName) {
        const next = Object.assign({}, root.expandedGroups);
        next[appName] = !next[appName];
        root.expandedGroups = next;
    }

    function groups() {
        // `expandedGroups` is read so the binding re-evaluates on toggle.
        const expanded = root.expandedGroups;
        const values = server ? server.tracked.values.slice() : [];
        values.reverse();
        const map = {};
        const order = [];
        for (let i = 0; i < values.length; ++i) {
            const n = values[i];
            const key = n.appName || "Unknown";
            if (!map[key]) {
                map[key] = [];
                order.push(key);
            }
            map[key].push(n);
        }
        const result = order.map(function (key) {
            const items = map[key];
            let critical = false;
            for (let j = 0; j < items.length; ++j)
                if (items[j].urgency === 2)
                    critical = true;
            return {
                appName: key,
                items: items,
                critical: critical,
                expanded: expanded[key] === true
            };
        });
        // Critical groups first; the rest keeps insertion order.
        result.sort(function (a, b) {
            return (b.critical ? 1 : 0) - (a.critical ? 1 : 0);
        });
        return result;
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

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.server !== null && root.server.unreadCount > 0
            text: root.server !== null ? root.server.unreadCount + " new" : ""
            color: Theme.teal
            font.family: "Adwaita Sans"
            font.pixelSize: 11
        }

        Pressable {
            width: dndLabel.implicitWidth + Tokens.space.s * 2
            height: 24

            onClicked: {
                if (root.server) {
                    root.server.dnd = !root.server.dnd;
                    Island.showDndOsd(root.server.dnd);
                }
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
            visible: root.server !== null && root.server.count > 0

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

    // --- The groups -------------------------------------------------------
    Repeater {
        model: root.groups()

        delegate: Column {
            id: groupColumn

            required property var modelData

            width: root.width
            spacing: 4

            // The group header, only when there is more than one.
            Pressable {
                width: parent.width
                height: 26
                visible: groupColumn.modelData.items.length > 1

                onClicked: root.toggleGroup(groupColumn.modelData.appName)

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Tokens.space.s

                    Item {
                        width: 16
                        height: 16
                        anchors.verticalCenter: parent.verticalCenter

                        Image {
                            anchors.fill: parent
                            visible: groupColumn.modelData.items[0].image !== ""
                                || groupColumn.modelData.items[0].appIcon !== ""
                            source: groupColumn.modelData.items[0].image !== ""
                                ? groupColumn.modelData.items[0].image
                                : Quickshell.iconPath(
                                    groupColumn.modelData.items[0].appIcon, true)
                            sourceSize.width: 16
                            sourceSize.height: 16
                            fillMode: Image.PreserveAspectFit
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: groupColumn.modelData.appName
                        color: Theme.fg0
                        font.family: "Adwaita Sans"
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: countLabel.implicitWidth + 10
                        height: 18
                        radius: 9
                        color: Theme.bg2

                        Text {
                            id: countLabel
                            anchors.centerIn: parent
                            text: groupColumn.modelData.items.length
                            color: Theme.fg1
                            font.family: "Adwaita Sans"
                            font.pixelSize: 11
                        }
                    }
                }

                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: Tokens.space.s
                    anchors.verticalCenter: parent.verticalCenter
                    text: groupColumn.modelData.expanded ? "󰅃" : "󰅀"
                    color: Theme.fg1
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                }
            }

            // The cards: the latest only, or all when expanded.
            Repeater {
                model: groupColumn.modelData.expanded
                    ? groupColumn.modelData.items
                    : groupColumn.modelData.items.slice(0, 1)

                delegate: NotificationItem {
                    width: root.width
                    server: root.server
                    receivedAt: root.stampMs(modelData.id)

                    onDismissed: {
                        if (root.server)
                            root.server.dismiss(modelData);
                    }
                }
            }
        }
    }

    Text {
        visible: root.server !== null && root.server.count === 0
        text: "No notifications"
        color: Theme.fg1
        font.family: "Adwaita Sans"
        font.pixelSize: 12
    }
}
