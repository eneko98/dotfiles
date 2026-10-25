// The same lock surface in a normal window, for testing the layout and PAM
// without locking the session. Run it with:
//
//   quickshell -p ~/.config/quickshell/lock-test.qml
//
// A correct password closes the window (Qt.quit) and writes to the log; a wrong
// one shows the failure line. No lock is taken, so a bad PAM config cannot leave
// the session stuck.

import Quickshell
import QtQuick

ShellRoot {
    LockContext {
        id: lockContext

        onUnlocked: {
            console.log("LOCK TEST: unlocked");
            Qt.quit();
        }
    }

    FloatingWindow {
        implicitWidth: 900
        implicitHeight: 600

        LockSurface {
            anchors.fill: parent
            context: lockContext
        }
    }
}
