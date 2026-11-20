// System metrics for the HUD: GPU load, shell CPU/PSS, memory pressure,
// zram compression, k10temp temperature and battery draw. Everything is read
// only while the HUD is enabled.
//
// procfs/sysfs files report size 0 and never emit inotify, so every read is an
// explicit reload() with blockLoading -- the same pattern as Resources.qml.
// The delta-based metrics (CPU%) need two samples one second apart.
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property real gpuPct: -1
    property real shellCpu: -1
    property real pssMB: 0
    property real psiPct: 0
    property real zramOrigGiB: 0
    property real zramUsedGiB: 0
    property real zramRatio: 0
    property real tempC: -1
    property real powerW: -1
    property string batteryStatus: ""

    // Video engine: 0..1 of one engine's wall time, from drm fdinfo deltas.
    // -1 until the first two samples exist.
    property real videoLoad: -1
    property string videoApp: ""
    property real _prevVideoNs: -1
    property real _prevVideoMs: 0

    property string gpuPath: ""
    property string currentPath: ""
    property string voltagePath: ""
    property string statusPath: ""
    property string tempPath: ""
    property string pid: ""
    property real ticksPerSecond: 100

    property int _prevCpuTicks: -1
    property real _prevCpuMs: 0

    onPidChanged: refresh()

    Connections {
        target: Config

        function onHudChanged() {
            if (!Config.hud) {
                root.videoLoad = -1;
                root._prevVideoNs = -1;
                return;
            }
            root.discover();
        }
    }

    Component.onCompleted: if (Config.hud) discover()

    function discover() {
        if (discoverProcess.running)
            return;
        discoverProcess.running = true;
    }

    function refresh() {
        if (!Config.hud || root.pid === "")
            return;

        statFile.reload();
        smapsFile.reload();
        gpuFile.reload();
        pressureFile.reload();
        zramFile.reload();
        tempFile.reload();
        currentFile.reload();
        voltageFile.reload();
        statusFile.reload();

        // utime (14) and stime (15) are 1-based fields 14/15, so indices 13/14.
        const parts = statFile.text().trim().split(/\s+/);
        if (parts.length >= 15) {
            const totalTicks = Number(parts[13]) + Number(parts[14]);
            const now = Date.now();
            if (root._prevCpuTicks >= 0 && now > root._prevCpuMs) {
                const dt = (now - root._prevCpuMs) / 1000;
                root.shellCpu = Math.min(999,
                    (totalTicks - root._prevCpuTicks)
                        / root.ticksPerSecond / dt * 100);
            }
            root._prevCpuTicks = totalTicks;
            root._prevCpuMs = now;
        }

        const pss = smapsFile.text().match(/Pss:\s*(\d+)/);
        if (pss !== null)
            root.pssMB = Number(pss[1]) / 1024;

        const rawGpu = gpuFile.text().trim();
        if (rawGpu !== "")
            root.gpuPct = Number(rawGpu);

        const pressure = pressureFile.text().split("\n");
        for (const line of pressure) {
            if (line.indexOf("some ") !== 0)
                continue;
            const avg = line.match(/avg10=([0-9.]+)/);
            if (avg !== null)
                root.psiPct = Number(avg[1]);
        }

        const zram = zramFile.text().trim().split(/\s+/);
        if (zram.length >= 2) {
            root.zramOrigGiB = Number(zram[0]) / 1073741824;
            root.zramUsedGiB = Number(zram[1]) / 1073741824;
            root.zramRatio = Number(zram[1]) > 0
                ? Number(zram[0]) / Number(zram[1]) : 0;
        }

        const rawTemp = tempFile.text().trim();
        if (rawTemp !== "")
            root.tempC = Number(rawTemp) / 1000;

        root.batteryStatus = statusFile.text().trim();

        // microamps * microvolts = 1e-12 W. current_now reads 0 while the
        // laptop is on AC (UPower reports 0 W there too), so the card says
        // "AC" rather than a fake 0.0 W.
        const current = Number(currentFile.text().trim());
        const voltage = Number(voltageFile.text().trim());
        if (isFinite(current) && isFinite(voltage) && voltage > 0)
            root.powerW = current * voltage / 1e12;
    }

    Process {
        id: discoverProcess
        command: ["sh", "-c", Quickshell.env("HOME") + "/.config/hypr/scripts/hud-discover"]

        stdout: StdioCollector {
            onStreamFinished: {
                for (const line of text.trim().split("\n")) {
                    const m = line.match(/^([a-z]+)=(.*)$/);
                    if (m === null)
                        continue;
                    const key = m[1], value = m[2].trim();
                    if (key === "gpu") root.gpuPath = value;
                    if (key === "current") root.currentPath = value;
                    if (key === "voltage") root.voltagePath = value;
                    if (key === "status") root.statusPath = value;
                    if (key === "temp") root.tempPath = value;
                    if (key === "pid") root.pid = value;
                    if (key === "ticks") root.ticksPerSecond = Number(value) || 100;
                }
            }
        }
    }

    FileView { id: statFile; path: root.pid === "" ? "" : "/proc/" + root.pid + "/stat"; blockLoading: true; printErrors: false }
    FileView { id: smapsFile; path: root.pid === "" ? "" : "/proc/" + root.pid + "/smaps_rollup"; blockLoading: true; printErrors: false }
    FileView { id: gpuFile; path: root.gpuPath; blockLoading: true; printErrors: false }
    FileView { id: pressureFile; path: "/proc/pressure/memory"; blockLoading: true; printErrors: false }
    FileView { id: zramFile; path: "/sys/block/zram0/mm_stat"; blockLoading: true; printErrors: false }
    FileView { id: tempFile; path: root.tempPath; blockLoading: true; printErrors: false }
    FileView { id: currentFile; path: root.currentPath; blockLoading: true; printErrors: false }
    FileView { id: voltageFile; path: root.voltagePath; blockLoading: true; printErrors: false }
    FileView { id: statusFile; path: root.statusPath; blockLoading: true; printErrors: false }

    // One process per second, and only with the HUD up: the focused window's
    // process tree is the thing whose decode path the user is asking about.
    Process {
        id: decodeProc
        command: ["sh", "-c", Quickshell.env("HOME") + "/.config/hypr/scripts/hud-decode"]

        stdout: StdioCollector {
            onStreamFinished: {
                const m = text.trim().split(/\s+/);
                if (m.length < 1)
                    return;
                const ns = Number(m[0]);
                if (!isFinite(ns))
                    return;
                root.videoApp = m.length > 1 ? m[1] : "";
                const now = Date.now();
                if (root._prevVideoNs >= 0 && now > root._prevVideoMs) {
                    const elapsedNs = (now - root._prevVideoMs) * 1e6;
                    root.videoLoad = Math.min(1,
                        (ns - root._prevVideoNs) / elapsedNs);
                }
                root._prevVideoNs = ns;
                root._prevVideoMs = now;
            }
        }
    }

    // No `running:` binding on the Process: Quickshell writes `running` when it
    // starts, which breaks the binding (measured with bt-agent). The timer owns
    // the cadence and the `Config.hud` guard.
    Timer {
        id: decodeTimer
        interval: 1000
        repeat: true
        running: Config.hud
        triggeredOnStart: true
        onTriggered: {
            if (!decodeProc.running)
                decodeProc.running = true;
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: Config.hud
        onTriggered: root.refresh()
    }
}
