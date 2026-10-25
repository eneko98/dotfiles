// The real lock: a separate Quickshell process started by
// config/hypr/scripts/lock. It must not live inside the bar's process: a bar
// reload would destroy the WlSessionLock while locked, and the compositor would
// leave the session painted with a solid color (the protocol's security
// property). Quitting after unlocking is equally deliberate.

import Quickshell
import Quickshell.Wayland
import QtQuick

ShellRoot {
    LockContext {
        id: lockContext

        onUnlocked: {
            lock.locked = false;
            Qt.quit();
        }
    }

    WlSessionLock {
        id: lock
        locked: true

        WlSessionLockSurface {
            color: Theme.bg0

            LockSurface {
                anchors.fill: parent
                context: lockContext
            }
        }
    }
}
