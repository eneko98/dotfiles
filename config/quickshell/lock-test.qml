// The lock's test harness: the same LockSurface + LockContext the real
// lock uses, in a FloatingWindow -- the layout and the PAM flow can be
// tried with the real password while the session is NOT locked. A correct
// password logs "LOCK TEST: unlocked" and quits the window; a wrong one
// shows the failure line. Run:
//   quickshell -p ~/.config/quickshell/lock-test.qml
import Quickshell
import QtQuick

FloatingWindow {
    id: win

    title: "lock test"
    color: Theme.bg0
    implicitWidth: 800
    implicitHeight: 500

    LockContext {
        id: ctx

        onUnlocked: {
            console.log("LOCK TEST: unlocked");
            Qt.quit();
        }
    }

    LockSurface {
        anchors.fill: parent
        context: ctx
    }
}
