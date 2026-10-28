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
    property bool dashboardVisible: false
    readonly property int interval: detailVisible || dashboardVisible ? 1000 : 2000

    property real cpu: 0             // 0..1
    property real memUsed: 0         // 0..1
    property real memUsedGiB: 0
    property real memTotalGiB: 0
    property real swapUsedGiB: 0
    property real swapTotalGiB: 0
    property real tempC: NaN
    property real load1: 0
    property real load5: 0
    property real load15: 0
    property real cpuMHz: NaN
    property var cpuHistory: []
    property var memHistory: []
    property var tempHistory: []

    // Disks: [{ mount, size, used, pct }], from `df`.
    property var disks: []

    // Network: the default interface, its IPv4, cumulative counters and the
    // rate derived between samples (bytes/s).
    property string netIface: ""
    property string netIp: ""
    property real netRxTotal: 0
    property real netTxTotal: 0
    property real netRxRate: 0
    property real netTxRate: 0

    // Alert state for the bar (brief 9.3).
    property string alert: ""        // "" | "cpu" | "mem" | "temp"
    property bool alertCritical: false

    property string tempPath: ""
    property var _prevCpu: null
    property int _cpuHot: 0
    property int _memHot: 0
    property int _tempHot: 0
    property real _prevRx: -1
    property real _prevTx: -1
    property real _prevNetTime: 0

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
    FileView { id: cpuinfoFile; path: "/proc/cpuinfo"; blockLoading: true }
    FileView { id: tempFile; path: res.tempPath; blockLoading: true }

    Timer {
        interval: res.interval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: res.sample()
    }

    // Disks change slowly: 5 s is plenty.
    Process {
        id: diskProc
        command: ["df", "-B1", "--output=target,size,used,pcent", "/", "/home", "/boot"]
        stdout: StdioCollector { onStreamFinished: res.parseDisks(text) }
    }

    Timer {
        interval: 5000
        running: res.dashboardVisible
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!diskProc.running) diskProc.running = true
    }

    // The default interface and its counters. One shell call: the route
    // decides the interface, sysfs gives the bytes and `ip` the address.
    Process {
        id: netProc
        command: ["sh", "-c", "iface=$(ip route get 1.1.1.1 2>/dev/null | sed -n 's/.* dev \\([^ ]*\\).*/\\1/p' | head -1); [ -z \"$iface\" ] && iface=$(ls /sys/class/net | grep -v '^lo$' | head -1); rx=$(cat /sys/class/net/$iface/statistics/rx_bytes 2>/dev/null || echo 0); tx=$(cat /sys/class/net/$iface/statistics/tx_bytes 2>/dev/null || echo 0); ipa=$(ip -4 -o addr show dev $iface scope global 2>/dev/null | awk '{print $4}' | head -1); echo \"$iface|$rx|$tx|$ipa\""]
        stdout: StdioCollector { onStreamFinished: res.parseNet(text) }
    }

    Timer {
        interval: 2000
        running: res.dashboardVisible
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!netProc.running) netProc.running = true
    }

    function parseDisks(text) {
        const lines = text.trim().split("\n");
        const out = [];
        // Skip df's header row.
        for (let i = 1; i < lines.length; ++i) {
            const parts = lines[i].trim().split(/\s+/);
            if (parts.length < 4)
                continue;
            const size = parseInt(parts[1]);
            if (isNaN(size) || size <= 0)
                continue;
            out.push({
                mount: parts[0],
                size: size,
                used: parseInt(parts[2]),
                pct: parseInt(parts[3])
            });
        }
        res.disks = out;
    }

    function parseNet(text) {
        const parts = text.trim().split("|");
        if (parts.length < 4)
            return;
        const now = Date.now();
        const rx = parseInt(parts[1]) || 0;
        const tx = parseInt(parts[2]) || 0;
        if (res._prevRx >= 0 && res._prevNetTime > 0) {
            const dt = (now - res._prevNetTime) / 1000;
            if (dt > 0) {
                res.netRxRate = Math.max(0, (rx - res._prevRx) / dt);
                res.netTxRate = Math.max(0, (tx - res._prevTx) / dt);
            }
        }
        res._prevRx = rx;
        res._prevTx = tx;
        res._prevNetTime = now;
        res.netIface = parts[0];
        res.netRxTotal = rx;
        res.netTxTotal = tx;
        res.netIp = parts[3];
    }

    function push(list, v) {
        return list.concat([v]).slice(-60);
    }

    function sample() {
        statFile.reload();
        memFile.reload();
        loadFile.reload();
        cpuinfoFile.reload();
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
        const loads = loadFile.text().trim().split(/\s+/);
        load1 = parseFloat(loads[0]) || 0;
        load5 = parseFloat(loads[1]) || 0;
        load15 = parseFloat(loads[2]) || 0;
        if (tempPath !== "") tempC = parseInt(tempFile.text()) / 1000;

        // Frequency: average of every core's current clock (/proc/cpuinfo).
        let mhzSum = 0;
        let mhzCount = 0;
        for (const l of cpuinfoFile.text().split("\n")) {
            if (l.startsWith("cpu MHz")) {
                mhzSum += parseFloat(l.split(":")[1]);
                mhzCount++;
            }
        }
        cpuMHz = mhzCount > 0 ? mhzSum / mhzCount : NaN;

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
