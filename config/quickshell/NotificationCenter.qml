// Notifications: the server that owns org.freedesktop.Notifications, the
// tracked list behind the Today panel and the receive-time stamps.
//
// Quickshell cannot share the bus name with mako, so this replaces it: mako's
// service is disabled while this is in the shell. Everything is tracked
// (`tracked = true`); the ISLAND is the arrival surface (push into the
// arbiter, which respects DND and keeps criticals); the Today panel lists
// the tracked ones and dismisses them.
//
// The read state lives here, not on the Notification object: `read` is a map
// of id -> true. The island marks a notification read after showing it, the
// shell marks it on dismiss, and opening Today marks them all.
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

    // The Today panel sets this while it is open: arrivals go straight to the
    // history and count as read (the user is looking at the list).
    property bool todayOpen: false

    // id -> true for notifications the user has seen.
    property var read: ({})

    readonly property int unreadCount: {
        const values = server.trackedNotifications.values;
        let unread = 0;
        for (let i = 0; i < values.length; ++i)
            if (!root.read[values[i].id])
                unread++;
        return unread;
    }

    function markRead(id) {
        if (!id || root.read[id])
            return;
        // Transient notifications are never tracked, so they have no read
        // state to keep; check before growing the map.
        let found = false;
        const values = server.trackedNotifications.values;
        for (let i = 0; i < values.length; ++i) {
            if (values[i].id === id) {
                found = true;
                break;
            }
        }
        if (!found)
            return;
        const next = Object.assign({}, root.read);
        next[id] = true;
        root.read = next;
    }

    function markAllRead() {
        const values = server.trackedNotifications.values;
        if (values.length === 0)
            return;
        const next = Object.assign({}, root.read);
        for (let i = 0; i < values.length; ++i)
            next[values[i].id] = true;
        root.read = next;
    }

    NotificationServer {
        id: server

        bodySupported: true
        bodyMarkupSupported: false
        imageSupported: true
        actionsSupported: true
        keepOnReload: true

        onNotification: function (notification) {
            // Transient notifications show on the island but never reach the
            // history (connects, "downloaded", progress flashes...).
            notification.tracked = !notification.transient;
            root.stamps[notification.id] = Date.now();

            // The island is the arrival surface; with Today open everything
            // goes to the list and counts as read.
            if (root.todayOpen) {
                root.markRead(notification.id);
                return;
            }

            // DND hides arrivals unless the notification is critical.
            if (!notification.lastGeneration && (!root.dnd || notification.urgency === 2))
                Island.push(notification);
            else
                root.markRead(notification.id);
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

    function invokeAction(notification, identifier) {
        if (!notification)
            return;
        const actions = notification.actions;
        for (let i = 0; i < actions.length; ++i) {
            if (actions[i].identifier === identifier) {
                actions[i].invoke();
                return;
            }
        }
    }

    function clearAll() {
        const values = server.trackedNotifications.values.slice();
        for (let i = 0; i < values.length; ++i)
            values[i].dismiss();
    }
}
