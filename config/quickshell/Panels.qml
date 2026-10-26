// Which panel is open, and where from. Popup instances report to it on their
// visibility changes, so exactly one panel is ever open across windows: open
// one and the previous one closes itself. The island arbiter reads `current`
// to suppress what the panel already shows (the volume OSD, for one).
//
// The stage's backdrop already closes a panel on outside clicks; this covers
// the programmatic path (a module popup opening while the control centre is
// up) without every caller having to know about every other panel.
pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root

    // The currently open Popup, or null. var, not Popup: a typed property
    // would make the singleton depend on the component.
    property var current: null

    function open(popup) {
        if (root.current && root.current !== popup) {
            root.current.close();
            root.current = null;
        }
        root.current = popup;
    }

    function closed(popup) {
        if (root.current === popup)
            root.current = null;
    }
}
