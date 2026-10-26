// The greeter's root. Runs under greetd on tty1 (cage -s -- quickshell -p here),
// and in a plain FloatingWindow for the demo (GREETER_DEMO=1).
//
// This is a separate Quickshell instance from the bar: greetd launches it as the
// greeter user from a system copy of this directory (the user's home is 0700).

import QtQuick
import Quickshell

ShellRoot {
    FloatingWindow {
        id: window

        // cage fullscreens its only toplevel; the size only matters in demo windows.
        implicitWidth: 1920
        implicitHeight: 1080
        color: Theme.bg0

        Greeter {
            anchors.fill: parent
        }
    }
}
