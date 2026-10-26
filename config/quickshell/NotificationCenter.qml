// Notifications: the server that owns org.freedesktop.Notifications, the toast
// queue that shows what just arrived, and the history panel behind the bell.
//
// Quickshell cannot share the bus name with mako, so this replaces it: mako's
// service is disabled while this is in the shell. Everything is tracked
// (`tracked = true`) so a dismissed toast still leaves the notification in the
// history; clicking a toast or a history entry dismisses it for real, and the
// history's "Clear all" dismisses everything.
//
// Notifications carried over from a reload (`lastGeneration`) are tracked but
// not toasted: they are old news by definition.

import Quickshell
import Quickshell.Services.Notifications
import QtQuick

Scope {
    id: root

    property bool dnd: false
    property int count: server.trackedNotifications.values.length
    property alias tracked: server.trackedNotifications
    property alias toasts: toastModel

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

    ListModel {
        id: toastModel
    }

    // Receive times for the history's relative timestamps (the Notification
    // type carries no date of its own). A reload loses the stamps of
    // notifications that arrived before it; those show as no time.
    property var stamps: ({})

    function stamp(id) {
        return root.stamps[id];
    }

    function addToast(notification) {
        root.stamps[notification.id] = Date.now();

        toastModel.append({
            summary: notification.summary || "(no summary)",
            body: notification.body,
            appName: notification.appName,
            appIcon: notification.appIcon,
            urgency: notification.urgency,
            notificationId: notification.id,
            timeout: notification.expireTimeout > 0 ? notification.expireTimeout : 5
        });

        // A stack of four is already a wall of text next to the bar.
        while (toastModel.count > 3)
            toastModel.remove(0);
    }

    // Find the live notification by id: the toast outlives neither the model nor
    // a reload, and an id is stable where an index is not.
    function notificationById(id) {
        const values = server.trackedNotifications.values;
        for (let i = 0; i < values.length; ++i)
            if (values[i].id === id)
                return values[i];
        return null;
    }

    function removeToast(id) {
        for (let i = 0; i < toastModel.count; ++i) {
            if (toastModel.get(i).notificationId === id) {
                toastModel.remove(i);
                return;
            }
        }
    }

    function dismissToast(id) {
        const notification = root.notificationById(id);
        if (notification !== null)
            notification.dismiss();
        root.removeToast(id);
    }

    function dismiss(notification) {
        notification.dismiss();
    }

    function clearAll() {
        const values = server.trackedNotifications.values.slice();
        for (let i = 0; i < values.length; ++i)
            values[i].dismiss();
    }

    function openHistory() {
        // The toasts would sit exactly on top of the history; the history is the
        // fuller view, so opening it retires the toasts.
        toastModel.clear();
        history.visible = true;
    }

    NotificationToasts {
        center: root
    }

    NotificationHistory {
        id: history
        center: root
    }
}
