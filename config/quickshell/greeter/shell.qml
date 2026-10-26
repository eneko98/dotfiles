// The greeter's root. Runs under greetd on tty1 (cage -s -- quickshell -p here),
// and in the demo from the repo.
//
// It is a layer-shell surface, not a FloatingWindow: cage draws no server-side
// decorations, so Qt would put its white CSD titlebar ("quickshell" plus
// minimize/maximize/close) on a normal toplevel. A layer surface has no
// decorations at all and fills the output; exclusive keyboard focus is what
// makes the password field typeable.

import QtQuick
import Quickshell
import Quickshell.Wayland

ShellRoot {
    PanelWindow {
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        color: Theme.bg0
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        Greeter {
            anchors.fill: parent
        }
    }
}
