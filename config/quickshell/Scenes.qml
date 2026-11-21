// Named desktop states that apply and revert as a whole. The singleton holds
// the active name and the definitions; the shell applies the effects, because
// a singleton cannot reference another one by name in this engine.
//
// Each scene lists only what it changes. The shell saves the previous value of
// every knob before applying, and restores that saved value on leave (not an
// assumed default).
pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root

    property string active: ""

    readonly property var definitions: ({
        cine: {
            label: "Cine",
            dnd: true,
            caffeine: true,
            dimInactive: false
        },
        music: {
            label: "Música",
            dnd: false,
            caffeine: false,
            dimInactive: true,
            spotify: true
        }
    })

    readonly property var names: ["cine", "music"]

    signal enter(string name)
    signal leave()

    function toggle(name) {
        if (root.active === name) {
            root.active = "";
            root.leave();
            return;
        }
        // Switching directly from one scene to another restores the first
        // one before applying the second, so the saved values stay original.
        if (root.active !== "")
            root.leave();
        root.active = name;
        root.enter(name);
    }

    function clear() {
        if (root.active === "")
            return;
        root.active = "";
        root.leave();
    }
}
