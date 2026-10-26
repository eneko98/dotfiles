// Night light, through hyprsunset's IPC. There is no queryable identity
// state (`hyprctl hyprsunset profile` reports none and `temperature` keeps
// the last value after identity), so the toggle owns the state for the
// session -- a Quickshell reload while it is on leaves the screen tinted
// with the switch reading Off. The known edge, unchanged from the current
// control centre.
pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root

    property bool on: false

    function toggle() {
        root.on = !root.on;

        if (root.on)
            Quickshell.execDetached(["hyprctl", "hyprsunset", "temperature", "4000"]);
        else
            Quickshell.execDetached(["hyprctl", "hyprsunset", "identity"]);
    }
}
