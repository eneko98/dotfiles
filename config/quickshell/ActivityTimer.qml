// A countdown as an island activity:
//   qs ipc call activity timer "Pizza" 600
// One timer at a time; starting another replaces it.
import QtQuick
import Quickshell

Scope {
    id: root

    property string label: ""
    property int total: 0
    property int remaining: 0
    property bool running: false

    function start(label, seconds) {
        root.label = label;
        root.total = Math.max(1, seconds);
        root.remaining = root.total;
        root.running = true;
        // Same id: reassign the activity so the island picks the new label
        // and the countdown restarts.
        Island.activityStart("timer", label);
        root.publish();
        tick.restart();
    }

    function publish() {
        if (!root.running)
            return;
        Island.activityProgress("timer",
            1 - root.remaining / root.total,
            format(root.remaining));
    }

    function format(seconds) {
        const m = Math.floor(seconds / 60);
        const s = seconds % 60;
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    function finish() {
        if (!root.running)
            return;
        root.running = false;
        tick.stop();
        Island.activityEnd("timer", true);
    }

    Timer {
        id: tick
        interval: 1000
        repeat: true

        onTriggered: {
            root.remaining -= 1;
            if (root.remaining <= 0) {
                root.remaining = 0;
                root.finish();
            } else {
                root.publish();
            }
        }
    }
}
