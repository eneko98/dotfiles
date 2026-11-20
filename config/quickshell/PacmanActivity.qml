// A pacman transaction as an island activity.
//
// The ALPM hooks run as root and cannot see the user's `qs` instance, so they
// publish a small file in /run/dotfiles (tmpfs, gone after a reboot). This
// component watches it, tails pacman.log for per-package progress while the
// transaction runs, and checks the pacman PID is still alive: a killed pacman
// never reaches the PostTransaction hook.
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    property int total: 0
    property int done: 0
    property int pid: 0
    property bool running: false

    function apply(s) {
        if (s.state === "running" && !root.running) {
            root.total = s.total || 0;
            root.pid = s.pid || 0;
            root.done = 0;
            root.running = true;
            Island.activityStart("pacman", "Updating");
            tailProc.running = true;
            aliveTimer.running = true;
        } else if (s.state === "done" && root.running) {
            root.finish(true);
        }
    }

    function finish(ok) {
        if (!root.running)
            return;
        root.running = false;
        tailProc.running = false;
        aliveTimer.running = false;
        Island.activityEnd("pacman", ok);
    }

    FileView {
        path: "/run/dotfiles/pacman.json"
        watchChanges: true
        printErrors: false

        onFileChanged: reload()

        onTextChanged: {
            const raw = text();
            if (raw === "")
                return;
            try {
                root.apply(JSON.parse(raw));
            } catch (e) {
                // A half-written file is not a transaction: ignore it.
            }
        }
    }

    Process {
        id: tailProc

        command: ["tail", "-n0", "-F", "/var/log/pacman.log"]

        stdout: SplitParser {
            onRead: function (line) {
                if (/\[ALPM\] (installed|upgraded|downgraded|reinstalled|removed) /.test(line)) {
                    root.done += 1;
                    Island.activityProgress("pacman",
                        root.total > 0 ? root.done / root.total : -1,
                        root.total > 0 ? root.done + "/" + root.total : "");
                }
            }
        }
    }

    // Liveness: the PostTransaction hook never runs if pacman is killed.
    Timer {
        id: aliveTimer
        interval: 2000
        repeat: true
        running: false
        onTriggered: alive.reload()
    }

    FileView {
        id: alive
        path: "/proc/" + root.pid + "/comm"
        printErrors: false

        onLoadFailed: function (error) {
            if (root.running)
                root.finish(false);
        }
    }
}
