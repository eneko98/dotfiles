// Top processes by CPU or memory, computed from /proc -- no daemon, and
// crucially no `ps %cpu`, which is the average since each process started,
// not current usage. The probe takes one sample of /proc/stat plus every
// /proc/[0-9]*/stat; usage per process is its utime+stime delta over the
// total CPU delta between two samples.
//
// Sampling runs only while `active` (the processes page on screen): two
// samples two seconds apart, and the first sample of a session has no
// deltas, so rows fill in on the second tick. Same-process names are
// grouped by default (one row per name, summed cpu/rss, pid list kept for
// ending).
//
// `canEnd` guards the kill: own uid only, and never the session's own
// machinery (compositor, shell, systemd, pipewire, greetd, dbus). The end
// action itself goes through a ConfirmButton in the UI; this file only
// runs the SIGTERM.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: procs

    property bool active: false
    property string sortBy: "cpu"        // "cpu" | "mem"
    property bool grouped: true
    property var rows: []                // [{ key, name, pids, cpu, rssBytes, own, canEnd }]

    readonly property var protectedNames: ["Hyprland", "quickshell", "qs", "uwsm", "systemd",
                                           "pipewire", "wireplumber", "greetd"]
    property int myUid: -1
    property var _prevTicks: ({})
    property real _prevTotal: 0

    Process {
        id: whoami
        running: true
        command: ["id", "-u"]
        stdout: StdioCollector { onStreamFinished: procs.myUid = parseInt(text) }
    }

    Process {
        id: probe
        command: ["sh", "-c", "head -n1 /proc/stat; echo @@; ps -eo pid=,uid=; echo @@; cat /proc/[0-9]*/stat 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: procs.parse(text)
        }
    }

    Timer {
        interval: 2000
        running: procs.active
        repeat: true
        triggeredOnStart: true
        onTriggered: probe.running = true
    }

    onActiveChanged: if (!active) {
        _prevTicks = {};
        _prevTotal = 0;
        rows = [];
    }

    function parse(text) {
        const parts = text.split("@@");
        if (parts.length < 3)
            return;

        const total = parts[0].trim().split(/\s+/).slice(1, 9).map(Number).reduce((a, b) => a + b, 0);
        const dTotal = _prevTotal > 0 ? total - _prevTotal : 0;

        // pid -> uid, for the "own processes only" guard.
        const uidOf = {};
        for (const l of parts[1].trim().split("\n")) {
            const f = l.trim().split(/\s+/);
            if (f.length === 2) uidOf[f[0]] = parseInt(f[1]);
        }

        // Per-process ticks. /proc/pid/stat's comm can contain spaces and
        // parens, so the name is everything between the FIRST "(" and the
        // LAST ")", and the numeric fields start after it; utime and stime
        // are fields 14/15 of the whole line (rest[11]/rest[12] here),
        // rss is field 24 in pages.
        const ticks = {};
        const list = [];
        for (const l of parts[2].split("\n")) {
            const open = l.indexOf("(");
            const close = l.lastIndexOf(")");
            if (open < 0 || close < 0) continue;
            const pid = l.slice(0, open).trim();
            const name = l.slice(open + 1, close);
            const rest = l.slice(close + 2).split(" ");
            const t = Number(rest[11]) + Number(rest[12]);
            const rss = Number(rest[21]) * 4096;
            ticks[pid] = t;
            const prev = _prevTicks[pid];
            const share = (dTotal > 0 && prev !== undefined) ? (t - prev) / dTotal : 0;
            list.push({ pid: pid, name: name, cpu: Math.max(0, share), rssBytes: rss,
                        own: uidOf[pid] === myUid });
        }
        _prevTicks = ticks;
        _prevTotal = total;

        let out = list;
        if (grouped) {
            const g = {};
            for (const p of list) {
                const k = p.name;
                if (!g[k]) g[k] = { key: k, name: k, pids: [], cpu: 0, rssBytes: 0, own: true };
                g[k].pids.push(p.pid);
                g[k].cpu += p.cpu;
                g[k].rssBytes += p.rssBytes;
                g[k].own = g[k].own && p.own;
            }
            out = Object.values(g);
        } else {
            out = list.map(p => ({ key: p.pid, name: p.name, pids: [p.pid], cpu: p.cpu,
                                   rssBytes: p.rssBytes, own: p.own }));
        }

        out.sort((a, b) => sortBy === "mem" ? b.rssBytes - a.rssBytes : b.cpu - a.cpu);
        rows = out.slice(0, 12).map(r => Object.assign(r, {
            canEnd: r.own && protectedNames.indexOf(r.name) < 0 && !r.name.startsWith("dbus")
        }));
    }

    function end(row) {
        if (!row.canEnd)
            return;
        killer.command = ["kill"].concat(row.pids);   // SIGTERM
        killer.running = true;
    }

    Process {
        id: killer
        // exited(exitCode, exitStatus) per the qmltypes; only failures are
        // interesting here.
        onExited: function (exitCode, exitStatus) {
            if (exitCode !== 0)
                console.warn("kill failed, exit code", exitCode);
        }
    }
}
