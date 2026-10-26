pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Caps Lock state from the LED class in sysfs. No inotify there, so it is
// polled, and only while someone is typing (watching = true).
Singleton {
    id: caps

    property bool watching: false
    property bool on: Config.demoCaps

    Process {
        id: probe

        command: ["sh", "-c", "cat /sys/class/leds/*::capslock/brightness 2>/dev/null"]

        stdout: StdioCollector {
            onStreamFinished: {
                if (Config.demoCaps)
                    return;
                caps.on = text.split("\n").some(function (line) {
                    const trimmed = line.trim();
                    return trimmed !== "" && trimmed !== "0";
                });
            }
        }
    }

    Timer {
        interval: 300
        repeat: true
        triggeredOnStart: true
        running: caps.watching && !Config.demoCaps
        onTriggered: probe.running = true
    }
}
