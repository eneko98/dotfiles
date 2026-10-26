// CPU, memory, zram swap, temperature and load, from /proc and /sys -- no
// daemon, just re-reads on a timer (brief 9). Sampled every 2 s, or every 1 s
// while a detail view (the resources section) is on screen. Each series keeps
// the last 60 samples for the sparklines; nothing animates between samples.
//
// The alert is the only state the bar itself shows, and it exists to be
// quiet: it appears only after the value has been over the line for ~10 s
// (5-point hysteresis at the 2 s cadence, recomputed for the fast cadence),
// and the entry threshold drops while the alert is lit so it does not
// flicker on and off. Critical (mem >= 95%, temp >= 95C) is immediate.
//
// procfs reads go through FileView with blockLoading; procfs files report
// size 0, which is the one thing worth having verified on the real system
// (it works on this Quickshell; if a version ever returns empty, the
// fallback is one Process running `cat` over the same files).
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: res

    property bool detailVisible: false
    readonly property int interval: detailVisible ? 1000 : 2000

    property real cpu: 0             // 0..1
    property real memUsed: 0         // 0..1
    property real memUsedGiB: 0
    property real memTotalGiB: 0
    property real swapUsedGiB: 0
    property real swapTotalGiB: 0
    property real tempC: NaN
    property real load1: 0
    property var cpuHistory: []
    property var memHistory: []
    property var tempHistory: []

    // Alert state for the bar (brief 9.3).
    property string alert: ""        // "" | "cpu" | "mem" | "temp"
    property bool alertCritical: false

    property string tempPath: ""
    property var _prevCpu: null
    property int _cpuHot: 0
    property int _memHot: 0
    property int _tempHot: 0

    // This machine is AMD, so the CPU sensor is k10temp.
    Process {
        id: findTemp
        running: true
        command: ["sh", "-c", "for d in /sys/class/hwmon/hwmon*; do [ \"$(cat \"$d/name\" 2>/dev/null)\" = k10temp ] && echo \"$d/temp1_input\" && break; done"]
        stdout: StdioCollector {
            onStreamFinished: res.tempPath = text.trim()
        }
    }

    FileView { id: statFile; path: "/proc/stat"; blockLoading: true }
    FileView { id: memFile; path: "/proc/meminfo"; blockLoading: true }
    FileView { id: loadFile; path: "/proc/loadavg"; blockLoading: true }
    FileView { id: tempFile; path: res.tempPath; blockLoading: true }

    Timer {
        interval: res.interval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: res.sample()
    }

    function push(list, v) {
        return list.concat([v]).slice(-60);
    }

    function sample() {
        statFile.reload();
        memFile.reload();
        loadFile.reload();
        if (tempPath !== "") tempFile.reload();

        // CPU: the first line of /proc/stat is the aggregate counter; usage
        // is 1 - (idle delta / total delta) since the previous sample.
        const line = statFile.text().split("\n")[0].trim().split(/\s+/).slice(1, 9).map(Number);
        const idle = line[3] + line[4];
        const total = line.reduce((a, b) => a + b, 0);
        if (_prevCpu) {
            const dt = total - _prevCpu.total;
            const di = idle - _prevCpu.idle;
            if (dt > 0) cpu = Math.min(1, Math.max(0, 1 - di / dt));
        }
        _prevCpu = { total: total, idle: idle };

        // Memory and zram swap: meminfo is kB.
        const m = {};
        for (const l of memFile.text().split("\n")) {
            const parts = l.split(/:\s+/);
            if (parts.length === 2) m[parts[0]] = parseInt(parts[1]);
        }
        if (m.MemTotal) {
            memUsed = 1 - m.MemAvailable / m.MemTotal;
            memTotalGiB = m.MemTotal / 1048576;
            memUsedGiB = (m.MemTotal - m.MemAvailable) / 1048576;
        }
        swapTotalGiB = (m.SwapTotal || 0) / 1048576;
        swapUsedGiB = ((m.SwapTotal || 0) - (m.SwapFree || 0)) / 1048576;

        // Load and temperature (millidegrees).
        load1 = parseFloat(loadFile.text().split(" ")[0]) || 0;
        if (tempPath !== "") tempC = parseInt(tempFile.text()) / 1000;

        cpuHistory = push(cpuHistory, cpu);
        memHistory = push(memHistory, memUsed);
        tempHistory = push(tempHistory, isNaN(tempC) ? 0 : tempC);

        updateAlert();
    }

    // ~10 s sustained, hysteresis: the entry threshold drops while the alert
    // is already lit, so a value hovering on the line does not flicker.
    function updateAlert() {
        const steps = Math.round(10000 / interval);
        _cpuHot = cpu >= (alert === "cpu" ? 0.80 : 0.85) ? _cpuHot + 1 : 0;
        _memHot = memUsed >= (alert === "mem" ? 0.80 : 0.85) ? _memHot + 1 : 0;
        _tempHot = tempC >= (alert === "temp" ? 80 : 85) ? _tempHot + 1 : 0;

        const memCritical = memUsed >= 0.95;
        const tempCritical = tempC >= 95;
        alertCritical = memCritical || tempCritical;

        if (tempCritical || _tempHot >= steps) alert = "temp";
        else if (memCritical || _memHot >= steps) alert = "mem";
        else if (_cpuHot >= steps) alert = "cpu";
        else alert = "";
    }
}
