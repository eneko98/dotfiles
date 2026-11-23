// The island's arbiter (brief 12): which live activity the island shows.
// The shell feeds the inputs -- volume/brightness changes (Pipewire and the
// backlight sysfs, watched there because singletons cannot reference each
// other in this engine) and notification arrivals from the server; the
// arbiter owns the state, the timers and the decision.
//
// Modes, flattened to what the island renders: "osd" (transient),
// "notification" (transient), "activity" (a long process with progress),
// "media" (the background state while something is playing) and "normal" (the
// clock row, when nothing is). A transient takes the island and gives it back
// to whatever was underneath (media, activity or the clock) when it ends; the
// OSD does not appear at all while the System panel is up -- the panel shows
// that control in full.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Singleton {
    id: island

    // --- OSD ---
    property string osdKind: ""     // "" | "volume" | "brightness" | "dnd"
    property real osdValue: 0       // 0..1
    property bool osdMuted: false
    property string osdText: ""     // for the DND OSD
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

    // --- Media ---
    // What is playing is the island's BACKGROUND state: it stays while there is
    // a track, and the transients (OSD, a notification, an activity such as a
    // pacman transaction) take the island and give it back when they end.
    //
    // The player is derived here instead of pushed by the pill: a selection
    // kept in a property needed a producer, a timer and a way to notice the
    // player disappearing. Same pick as the pill (first playing, else the first
    // with a title) and a title is required, because playerctld registers as an
    // MPRIS player with nothing behind it.
    readonly property var mediaPlayer: {
        const players = Mpris.players.values;
        let fallback = null;

        for (let i = 0; i < players.length; ++i) {
            if (players[i].trackTitle === "")
                continue;
            if (players[i].isPlaying)
                return players[i];
            if (fallback === null)
                fallback = players[i];
        }

        return fallback;
    }

    readonly property bool mediaPlaying: mediaPlayer !== null
        && mediaPlayer.isPlaying

    // Demo override for tests and captures (the `bar demo` IPC later).
    property string demoMode: ""

    // --- Activity ---
    // A long-running process with progress (a pacman transaction, a VM boot,
    // a download). It is not a notification: it stays until it ends. At most
    // one is on screen; the others wait in the map and show a "+N" chip.
    property var activities: ({})       // id -> { label, value, text, startedAt }
    property string activityId: ""      // the one on screen

    readonly property int activityCount: Object.keys(activities).length
    readonly property var currentActivity: activityId !== "" && activities[activityId]
        ? activities[activityId] : null
    readonly property real activityValue: currentActivity ? currentActivity.value : -1
    readonly property string activityText: currentActivity ? currentActivity.text : ""

    signal activityEnded(string id, string label, bool ok, int ms)

    readonly property string mode: {
        if (demoMode !== "")
            return demoMode;
        if (osdKind !== "")
            return "osd";
        if (current !== null)
            return "notification";
        if (activityId !== "")
            return "activity";
        if (mediaPlayer !== null)
            return "media";
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

    // A `value` hint (0-100) turns the countdown line into a progress bar
    // and stops the auto-dismiss: the notification stays until the app
    // updates it or the user dismisses it.
    readonly property bool hasProgress: current !== null
        && current.hints !== undefined
        && current.hints["value"] !== undefined
    readonly property real progressValue: hasProgress
        ? Number(current.hints["value"]) : 0

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

    function toggleMedia() {
        if (island.mediaPlayer !== null)
            island.mediaPlayer.togglePlaying();
    }

    function showDndOsd(on) {
        island.osdKind = "dnd";
        island.osdText = on ? "Do not disturb on" : "Do not disturb off";
        osdTimer.restart();
    }

    // --- Activity lifecycle. Reassign the map on every change: mutating a
    // var in place does not notify QML bindings.

    function activityStart(id, label) {
        const a = Object.assign({}, island.activities);
        a[id] = { label: label, value: -1, text: "", startedAt: Date.now() };
        island.activities = a;
        island.activityId = id;
    }

    function activityProgress(id, value, text) {
        if (!(id in island.activities))
            return;
        const prev = island.activities[id];
        const label = text || "";
        // Avoid relayout storms: ignore steps under 1 % unless the text changes.
        if (prev.value >= 0 && Math.abs(value - prev.value) < 0.01
            && label === prev.text)
            return;
        const a = Object.assign({}, island.activities);
        a[id] = Object.assign({}, prev, { value: value, text: label });
        island.activities = a;
    }

    function activityEnd(id, ok) {
        if (!(id in island.activities))
            return;
        const a = Object.assign({}, island.activities);
        const ended = a[id];
        delete a[id];
        island.activities = a;
        const ids = Object.keys(a);
        island.activityId = ids.length ? ids[ids.length - 1] : "";
        island.activityEnded(id, ended.label, ok, Date.now() - ended.startedAt);
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
        // Low: 3s; normal: 4s; the app's expireTimeout wins when it asks for
        // one (clamped to 2-10s); critical or progress notifications have no
        // countdown.
        if (island.hasProgress) {
            notifAnim.stop();
        } else if (n.urgency !== 2) {
            let ms = n.urgency === 0 ? 3000 : 4000;
            if (n.expireTimeout > 0)
                ms = Math.max(2000, Math.min(10000, n.expireTimeout));
            notifAnim.duration = ms;
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

    // Scroll navigation: rotate the queue without dismissing anything.
    function advance() {
        if (island.queue.length === 0)
            return;
        const cur = island.current;
        const following = island.queue[0];
        island.queue = island.queue.slice(1);
        if (cur !== null)
            island.queue = island.queue.concat([cur]);
        island.show(following);
    }

    function back() {
        if (island.queue.length === 0)
            return;
        const cur = island.current;
        const previous = island.queue[island.queue.length - 1];
        island.queue = island.queue.slice(0, -1);
        if (cur !== null)
            island.queue = [cur].concat(island.queue);
        island.show(previous);
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
        easing.type: Easing.Linear
        onFinished: island.dismissCurrent()
    }

    // Pause the countdown while hovered or while an OSD is showing. Only
    // touch the property when the animation is running; otherwise Qt warns
    // (and ignores) the setPaused call.
    function syncPause() {
        if (!notifAnim.running)
            return;
        const wantPause = island.hovered || island.osdKind !== "";
        if (notifAnim.paused !== wantPause)
            notifAnim.paused = wantPause;
    }

    Connections {
        target: island
        function onHoveredChanged() { island.syncPause(); }
        function onOsdKindChanged() { island.syncPause(); }
    }

    onCurrentChanged: {
        // When a new notification arrives, make sure the countdown is not
        // left paused by a previous hover/OSD state.
        if (notifAnim.running)
            notifAnim.paused = false;
    }
}
