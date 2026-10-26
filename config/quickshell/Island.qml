// The island's arbiter (brief 12): which live activity the island shows.
// The shell feeds the inputs -- volume/brightness changes (Pipewire and the
// backlight sysfs, watched there because singletons cannot reference each
// other in this engine) and notification arrivals from the server; the
// arbiter owns the state, the timers and the decision.
//
// Modes, flattened to what the island renders: "osd" (transient), 
// "notification" (transient), "normal" (the clock row: media and idle live
// there). A transient returns to normal when its timer ends; the OSD does
// not appear at all while the System panel is up -- the panel shows that
// control in full.
pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: island

    // --- OSD ---
    property string osdKind: ""     // "" | "volume" | "brightness"
    property real osdValue: 0       // 0..1
    property bool osdMuted: false
    property bool systemPanelOpen: false

    // --- Notification ---
    property var current: null
    property var queue: []
    property bool hovered: false
    property bool unread: false

    // Demo override for tests and captures (the `bar demo` IPC later).
    property string demoMode: ""

    readonly property string mode: {
        if (demoMode !== "")
            return demoMode;
        if (osdKind !== "")
            return "osd";
        if (current !== null)
            return "notification";
        return "normal";
    }

    // The notification countdown, 1 -> 0, for the 2px line at the island's
    // base. Paused while hovered.
    property real progress: 1

    function showOsd(kind, value, muted) {
        if (island.systemPanelOpen)
            return;
        island.osdKind = kind;
        island.osdValue = value;
        island.osdMuted = muted;
        osdTimer.restart();
    }

    function push(notification) {
        island.unread = true;
        if (island.current !== null) {
            island.queue = island.queue.concat([notification]);
            return;
        }
        island.show(notification);
    }

    function show(n) {
        island.current = n;
        island.progress = 1;
        // Low: 3s; normal: 4s; critical: no countdown -- it stays until the
        // user opens the island (which leads to Today's list).
        notifTimer.interval = n.urgency === 2 ? 100000
            : (n.urgency === 0 ? 3000 : 4000);
        notifAnim.duration = notifTimer.interval;
        notifAnim.restart();
        notifTimer.restart();
    }

    function dismissCurrent() {
        notifTimer.stop();
        notifAnim.stop();
        if (island.queue.length > 0) {
            const next = island.queue[0];
            island.queue = island.queue.slice(1);
            island.show(next);
        } else {
            island.current = null;
        }
    }

    function clearUnread() {
        island.unread = false;
    }

    Timer {
        id: osdTimer
        interval: 1200
        onTriggered: island.osdKind = ""
    }

    Timer {
        id: notifTimer
        onTriggered: island.dismissCurrent()
    }

    NumberAnimation {
        id: notifAnim
        target: island
        property: "progress"
        from: 1
        to: 0
        paused: island.hovered
        easing.type: Easing.Linear
    }

    onHoveredChanged: {
        if (island.current === null || island.current.urgency === 2)
            return;
        // Hover pauses the countdown; leaving restarts it (full time -- the
        // brief allows the simple version).
        if (island.hovered) {
            notifTimer.stop();
            notifAnim.pause();
        } else {
            notifTimer.restart();
            notifAnim.resume();
        }
    }
}
