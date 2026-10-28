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
//
// The history survives the session: a snapshot is written to
// $XDG_STATE_HOME/dotfiles/notifications.json and restored on startup.
// Quickshell's own persistenceSupported is only the capability advertisement,
// so the store below is what actually persists the cards.

import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import QtQuick

Scope {
    id: root

    property bool dnd: false
    property var restored: []       // plain objects from the previous session
    property bool restoredLoaded: false

    property alias tracked: server.trackedNotifications

    // Restored entries that no live notification shadows: ids are reused
    // across sessions, so the live one wins.
    readonly property int count: {
        const live = server.trackedNotifications.values;
        const ids = {};
        for (let i = 0; i < live.length; ++i)
            ids["n:" + live[i].id] = true;
        let extra = 0;
        for (let j = 0; j < root.restored.length; ++j)
            if (!ids[root.restored[j].uid])
                extra++;
        return live.length + extra;
    }

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
        root.scheduleSave();
    }

    function markAllRead() {
        const values = server.trackedNotifications.values;
        if (values.length === 0)
            return;
        const next = Object.assign({}, root.read);
        for (let i = 0; i < values.length; ++i)
            next[values[i].id] = true;
        root.read = next;
        root.scheduleSave();
    }

    function isRead(n) {
        if (!n)
            return true;
        if (n.restored)
            return n.read === true;
        return root.read[n.id] === true;
    }

    // --- Persistence ------------------------------------------------------
    // Quickshell's persistenceSupported only advertises the capability to
    // clients; the snapshot is ours. Read once at startup, written on change
    // with a short debounce.
    FileView {
        id: store

        path: {
            const state = Quickshell.env("XDG_STATE_HOME");
            const base = state !== "" ? state
                : Quickshell.env("HOME") + "/.local/state";
            return base + "/dotfiles/notifications.json";
        }
        blockLoading: true
        printErrors: false
    }

    Timer {
        id: saveTimer
        interval: 500
        onTriggered: root.save()
    }

    function scheduleSave() {
        if (root.restoredLoaded)
            saveTimer.restart();
    }

    function loadRestored() {
        const raw = store.text();
        let data = [];
        if (raw !== "" && raw.trim() !== "") {
            try {
                const parsed = JSON.parse(raw);
                if (Array.isArray(parsed))
                    data = parsed;
            } catch (e) {
                data = [];
            }
        }
        // Restored entries are never "new": they were already seen last
        // session, so they never carry the unread dot.
        root.restored = data.map(function (n) {
            return {
                restored: true,
                id: n.id,
                uid: n.uid || ("r:" + n.id),
                appName: n.appName || "",
                appIcon: n.appIcon || "",
                image: n.image || "",
                summary: n.summary || "",
                body: n.body || "",
                urgency: n.urgency || 1,
                receivedAt: n.receivedAt || 0,
                read: true
            };
        });
        root.restoredLoaded = true;
    }

    function save() {
        const now = Date.now();
        const live = server.trackedNotifications.values.map(function (n) {
            return {
                id: n.id,
                uid: "n:" + n.id,
                appName: n.appName,
                appIcon: n.appIcon,
                image: n.image,
                summary: n.summary,
                body: n.body,
                urgency: n.urgency,
                receivedAt: root.stamps[n.id] || now,
                read: root.read[n.id] === true
            };
        });
        store.setText(JSON.stringify(root.restored.concat(live).slice(-100)));
    }

    Component.onCompleted: root.loadRestored()

    NotificationServer {
        id: server

        bodySupported: true
        bodyMarkupSupported: false
        imageSupported: true
        actionsSupported: true
        keepOnReload: true
        persistenceSupported: true

        onNotification: function (notification) {
            // Transient notifications show on the island but never reach the
            // history (connects, "downloaded", progress flashes...).
            notification.tracked = !notification.transient;
            root.stamps[notification.id] = Date.now();
            root.scheduleSave();

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
        if (!notification)
            return;
        if (notification.restored) {
            root.restored = root.restored.filter(function (n) {
                return n.uid !== notification.uid;
            });
            root.scheduleSave();
            return;
        }
        notification.dismiss();
        root.scheduleSave();
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
        root.restored = [];
        root.scheduleSave();
    }
}
