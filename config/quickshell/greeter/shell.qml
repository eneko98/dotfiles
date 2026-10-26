// The greeter's root. Runs under greetd on tty1 (cage -s -- quickshell -p here),
// and in the demo from the repo.
//
// It is a normal toplevel, not a layer-shell PanelWindow: cage is a minimal
// kiosk compositor without wlr-layer-shell ("Failed to initialize layershell
// integration" in the Quickshell log, leaving a black screen with no surface).
// cage shows its only toplevel fullscreen, and QT_WAYLAND_DISABLE_WINDOWDECORATION=1
// in the greetd command stops Qt from drawing its own CSD titlebar.

import QtQuick
import Quickshell

ShellRoot {
    FloatingWindow {
        id: window

        implicitWidth: 1920
        implicitHeight: 1080
        fullscreen: true
        color: Theme.bg0

        Greeter {
            anchors.fill: parent
        }
    }
}
