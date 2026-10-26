// Caffeine mode: keep the session awake. A systemd-inhibit process runs while
// active, blocking idle, sleep and lid-switch. The toggle lives in the System
// panel's tile grid.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool active: false

    function toggle() {
        root.active = !root.active;
    }

    // The inhibitor process: blocks idle/sleep/lid while it lives.
    Process {
        id: inhibitor

        command: [
            "systemd-inhibit",
            "--what=idle:sleep:handle-lid-switch",
            "--who=quickshell-bar",
            "--why=Caffeine mode",
            "--mode=block",
            "sh", "-c", "while :; do sleep 86400; done"
        ]

        running: root.active
    }
}
