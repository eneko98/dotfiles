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

    // The shell wires these to NotificationCenter (singletons cannot see
    // each other): "read" after one second on screen, "dismissed" when the
    // user or the countdown takes it off the island (it stays in history).
    signal read(int id)
    signal dismissed(int id)

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
    // base. Paused while hovered or while the OSD is up.
    property real progress: 1

    // The current notification's body, stripped of HTML and decoded (some apps
    // send markup even though we do not advertise bodyMarkupSupported).
    readonly property string currentBody: current !== null ? cleanBody(current.body) : ""

    // Notifications waiting behind the one on screen.
    readonly property int pendingCount: queue.length

    function cleanBody(text) {
        if (!text)
            return "";
        return text
            .replace(/<[^>]*>/g, " ")
            .replace(/&amp;/g, "&")
            .replace(/&lt;/g, "<")
            .replace(/&gt;/g, ">")
            .replace(/&quot;/g, "\"")
            .replace(/&#0?39;/g, "'")
            .replace(/&nbsp;/g, " ")
            .replace(/\s+/g, " ")
            .trim();
    }

    function showOsd(kind, value, muted) {
        if (island.systemPanelOpen)
            return;
        island.osdKind = kind;
        island.osdValue = value;
        island.osdMuted = muted;
        osdTimer.restart();
    }

    function push(notification) {
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
        if (n.urgency !== 2) {
            notifAnim.duration = n.urgency === 0 ? 3000 : 4000;
            notifAnim.restart();
        } else {
            notifAnim.stop();
        }
        readTimer.restart();
    }

    function next() {
        if (island.queue.length > 0) {
            const following = island.queue[0];
            island.queue = island.queue.slice(1);
            island.show(following);
        } else {
            island.current = null;
        }
    }

    function dismissCurrent() {
        notifAnim.stop();
        readTimer.stop();
        if (island.current !== null)
            island.dismissed(island.current.id);
        island.next();
    }

    // Middle click: drop the whole queue (they stay in history as seen).
    function clearQueue() {
        for (let i = 0; i < island.queue.length; ++i)
            island.dismissed(island.queue[i].id);
        island.queue = [];
        island.next();
    }

    Timer {
        id: osdTimer
        interval: 1200
        onTriggered: island.osdKind = ""
    }

    // One second on screen counts as read.
    Timer {
        id: readTimer
        interval: 1000
        onTriggered: {
            if (island.current !== null)
                island.read(island.current.id);
        }
    }

    NumberAnimation {
        id: notifAnim
        target: island
        property: "progress"
        from: 1
        to: 0
        paused: island.hovered || island.osdKind !== ""
        easing.type: Easing.Linear
        onFinished: island.dismissCurrent()
    }

    onHoveredChanged: {
        if (island.current === null || island.current.urgency === 2)
            return;
        // Hover pauses the countdown; leaving resumes it from where it was.
        if (island.hovered)
            notifAnim.pause();
        else
            notifAnim.resume();
    }
}
