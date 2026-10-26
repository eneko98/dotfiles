// Notifications: the server that owns org.freedesktop.Notifications, the
// tracked list behind the Today panel and the receive-time stamps.
//
// Quickshell cannot share the bus name with mako, so this replaces it: mako's
// service is disabled while this is in the shell. Everything is tracked
// (`tracked = true`); the ISLAND is the arrival surface (push into the
// arbiter, which respects DND and keeps criticals); the Today panel lists
// the tracked ones and dismisses them.
//
// Notifications carried over from a reload (`lastGeneration`) are tracked
// but not pushed to the island: they are old news by definition.

import Quickshell
import Quickshell.Services.Notifications
import QtQuick

Scope {
    id: root

    property bool dnd: false
    property int count: server.trackedNotifications.values.length
    property alias tracked: server.trackedNotifications

    NotificationServer {
        id: server

        bodySupported: true
        bodyMarkupSupported: false
        imageSupported: false
        actionsSupported: false
        keepOnReload: true

        onNotification: function (notification) {
            notification.tracked = true;

            // The island is the arrival surface now (the toasts retired):
            // DND hides arrivals unless the notification is critical.
            if (!notification.lastGeneration && (!root.dnd || notification.urgency === 2))
                Island.push(notification);
        }
    }

    // Receive times for the history's relative timestamps (the Notification
    // type carries no date of its own). A reload loses the stamps of
    // notifications that arrived before it; those show as no time.
    property var stamps: ({})

    function stamp(id) {
        return root.stamps[id];
    }

    function dismiss(notification) {
        notification.dismiss();
    }

    function clearAll() {
        const values = server.trackedNotifications.values.slice();
        for (let i = 0; i < values.length; ++i)
            values[i].dismiss();
    }
}
