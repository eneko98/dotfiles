// The facts a fetch widget shows: the same story as the terminal's fastfetch,
// but live. Static rows are read once from files (no processes); the dynamic
// ones either come from Resources (already sampling for the dashboard) or are
// owned here.
//
// Singletons cannot reference each other in this engine, so anything that
// needs Resources is read by the widget, not by this file. The shell calls
// refreshPackages() when a pacman/paru activity ends -- counting the entries
// in pacman's local database is one directory listing, not a `pacman -Q`.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // --- Static, read once ------------------------------------------------
    property string distro: ""
    property string arch: ""
    property string kernel: ""
    property string host: ""
    property string wm: "Hyprland"
    property string cpuModel: ""
    property int packages: 0

    readonly property string user: Quickshell.env("USER") || "user"
    readonly property string shell: {
        const path = Quickshell.env("SHELL") || "";
        return path !== "" ? path.split("/").pop() : "";
    }

    // --- Dynamic ---------------------------------------------------------
    // Uptime: read once, then it is arithmetic on the wall clock -- /proc
    // files have no size and no inotify, the usual lesson.
    property real upSec: 0

    // Root filesystem, refreshed only while a widget is on screen.
    property var disk: ({ used: 0, total: 0 })
    property bool watched: false

    // --- Static reads -----------------------------------------------------
    // A real file: FileView loads it on its own.
    FileView {
        path: "/etc/os-release"
        printErrors: false

        onLoaded: {
            const m = text().match(/^PRETTY_NAME="?([^"\n]*)"?/m);
            if (m !== null)
                root.distro = m[1];
        }
    }

    // procfs: size 0, so blockLoading + an explicit reload.
    FileView {
        path: "/proc/sys/kernel/osrelease"
        printErrors: false
        blockLoading: true

        onLoaded: root.kernel = "Linux " + text().trim()
        Component.onCompleted: reload()
    }

    FileView {
        path: "/proc/sys/kernel/hostname"
        printErrors: false
        blockLoading: true

        onLoaded: root.host = text().trim()
        Component.onCompleted: reload()
    }

    // The CPU model name lives in /proc/cpuinfo with the frequencies; only
    // the first "model name" line is needed.
    FileView {
        path: "/proc/cpuinfo"
        printErrors: false
        blockLoading: true

        onLoaded: {
            const m = text().match(/^model name\s*:\s*(.+)$/m);
            if (m !== null)
                root.cpuModel = m[1].replace(/\s+/g, " ").trim();
        }
        Component.onCompleted: reload()
    }

    FileView {
        path: "/proc/uptime"
        printErrors: false
        blockLoading: true

        // The first number is the uptime in seconds (with decimals); the
        // clock takes it from there.
        onLoaded: root.upSec = parseFloat(text().split(" ")[0]) || 0
        Component.onCompleted: reload()
    }

    // One-shot commands, at start and on demand.
    Process {
        id: archProc

        command: ["uname", "-m"]
        stdout: StdioCollector {
            onStreamFinished: root.arch = text.trim()
        }
        Component.onCompleted: archProc.running = true
    }

    // `hyprctl version` prints "Tag: v0.57.2"; one process at start.
    Process {
        id: wmProc

        command: ["hyprctl", "version"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = text.match(/Tag:\s*(\S+)/);
                if (m !== null)
                    root.wm = "Hyprland " + m[1].replace(/^v/, "");
            }
        }
        Component.onCompleted: wmProc.running = true
    }

    // The number of installed packages is the number of entries in pacman's
    // local database (minus the ALPM_DB_VERSION marker file): one directory
    // listing, not the ~100 ms of `pacman -Q`.
    Process {
        id: pkgProc

        command: ["sh", "-c",
            "ls /var/lib/pacman/local | grep -v ALPM_DB_VERSION | wc -l"]

        stdout: StdioCollector {
            onStreamFinished: {
                const n = parseInt(text.trim());
                if (!isNaN(n))
                    root.packages = n;
            }
        }
    }

    function refreshPackages() {
        if (!pkgProc.running)
            pkgProc.running = true;
    }

    Component.onCompleted: root.refreshPackages()

    // --- Dynamic reads ----------------------------------------------------
    // The uptime ticks without reading anything again: wall clock minus the
    // starting reading.
    property real upAt: 0
    onUpSecChanged: root.upAt = Date.now()

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true

        onTriggered: {
            if (root.upSec > 0)
                root.upSec += 1;
        }
    }

    // Root filesystem, while a widget watches. df over the whole second grid
    // would be waste: 30 s is plenty for a number that moves by megabytes.
    Process {
        id: diskProc

        command: ["df", "-B1", "--output=used,size", "/"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                if (lines.length < 2)
                    return;
                const used = parseInt(lines[1].trim().split(/\s+/)[0]);
                const total = parseInt(lines[1].trim().split(/\s+/)[1]);
                if (!isNaN(used) && !isNaN(total))
                    root.disk = { used: used, total: total };
            }
        }
    }

    // The first version had `running: watched && !diskProc.running` with
    // triggeredOnStart: every time df finished, the timer armed itself again
    // and fired another df immediately -- a df loop that cost a third of a
    // core (measured). The timer now runs on its own interval and only skips
    // a tick while a df is still in flight; the first read is a one-shot when
    // a widget starts watching.
    Timer {
        interval: 30000
        running: root.watched
        repeat: true

        onTriggered: if (!diskProc.running)
            diskProc.running = true
    }

    onWatchedChanged: {
        if (root.watched && !diskProc.running)
            diskProc.running = true;
    }
}
