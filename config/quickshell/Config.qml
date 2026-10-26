// Shell configuration that the user can flip at runtime: the bar's layout
// and reduced motion. Persisted in one JSON file in the state dir (state,
// not config -- the repo carries no copy), written by the JsonAdapter
// automatically and read back on the next start.
//
// Motion binds its `reduced` to `reducedMotion`, so the IPC and the
// persisted value land on every animation in this process -- the lock runs
// its own Quickshell instance and picks it up through the same file.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // "tiers" (B) today; "island" (A) and "frame" (C) arrive with their
    // layouts.
    property string barLayout: "tiers"
    property bool reducedMotion: false

    readonly property string stateDir: Quickshell.env("XDG_STATE_HOME")
        || (Quickshell.env("HOME") + "/.local/state")

    FileView {
        id: stateFile

        path: root.stateDir + "/dotfiles/bar-state.json"
        printErrors: false

        JsonAdapter {
            id: adapter

            property string barLayout: root.barLayout
            property bool reducedMotion: root.reducedMotion
        }
    }

    Component.onCompleted: {
        const stored = adapter.barLayout;
        if (stored === "tiers" || stored === "island" || stored === "frame")
            root.barLayout = stored;
        root.reducedMotion = adapter.reducedMotion;
    }

    function setLayout(name) {
        if (name !== "tiers" && name !== "island" && name !== "frame")
            return false;
        root.barLayout = name;
        adapter.barLayout = name;
        stateFile.writeAdapter();
        return true;
    }

    function setReducedMotion(on) {
        root.reducedMotion = on;
        adapter.reducedMotion = on;
        stateFile.writeAdapter();
    }
}
