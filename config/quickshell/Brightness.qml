// Screen brightness, through brightnessctl: read with `-m` on start and on
// demand, written through a 90 ms debounce so a drag does not spawn one
// process per pixel. `percent` is the shared source for the section slider
// and (later) the OSD.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property int percent: 100
    property int _pending: -1

    function refresh() {
        reader.running = false;
        reader.running = true;
    }

    function set(fraction) {
        root.percent = Math.max(1, Math.round(fraction * 100));
        root._pending = root.percent;
        debounce.restart();
    }

    Process {
        id: reader
        command: ["brightnessctl", "-m"]

        stdout: SplitParser {
            onRead: function (line) {
                const parts = line.trim().split(",");
                if (parts.length < 4)
                    return;
                const value = parseInt(parts[3]);
                if (!isNaN(value))
                    root.percent = value;
            }
        }
    }

    Timer {
        id: debounce
        interval: 90
        onTriggered: {
            if (root._pending < 0)
                return;
            Quickshell.execDetached(["brightnessctl", "set", root._pending + "%"]);
            root._pending = -1;
        }
    }

    Component.onCompleted: root.refresh()
}
