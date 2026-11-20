// Shell configuration that the user can flip at runtime: the bar's layout
// and reduced motion. Persisted in one JSON file in the state dir (state,
// not config -- the repo carries no copy), written by the JsonAdapter
// automatically and read back on the next start.
//
// Motion.reduced is wired to this from shell.qml (singletons cannot
// reference each other by name in this engine -- measured); the lock's own
// Quickshell instance picks reduced motion up through the same file.
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

    // The active scene ("" = none) and the values it replaced, as JSON, so a
    // shell reload keeps both the scene and the way back.
    property string scene: ""
    property string sceneSaved: ""

    // The measurement HUD is an inspection tool, not a default-on overlay:
    // false at boot, persisted through the same state file as scenes.
    property bool hud: false

    readonly property string stateDir: Quickshell.env("XDG_STATE_HOME")
        || (Quickshell.env("HOME") + "/.local/state")

    FileView {
        id: stateFile

        path: root.stateDir + "/dotfiles/bar-state.json"
        printErrors: false

        onLoaded: root.adopt()

        JsonAdapter {
            id: adapter

            property string barLayout: root.barLayout
            property bool reducedMotion: root.reducedMotion
            property string scene: root.scene
            property string sceneSaved: root.sceneSaved
            property bool hud: root.hud
        }
    }

    // Emitted when the state file has been read (or re-read). The shell uses
    // it to apply a persisted scene after the file exists, which is later
    // than Component.onCompleted.
    signal loaded()

    Component.onCompleted: root.adopt()

    function adopt() {
        const stored = adapter.barLayout;
        if (stored === "tiers" || stored === "island" || stored === "frame")
            root.barLayout = stored;
        root.reducedMotion = adapter.reducedMotion;
        root.scene = adapter.scene;
        root.sceneSaved = adapter.sceneSaved;
        root.hud = adapter.hud;
        root.loaded();
    }

    function saveHud(on) {
        root.hud = on;
        adapter.hud = on;
        stateFile.writeAdapter();
        if (!on)
            Perf.clear();
    }

    function setLayout(name) {
        if (name !== "tiers" && name !== "island" && name !== "frame")
            return false;
        root.barLayout = name;
        adapter.barLayout = name;
        stateFile.writeAdapter();
        return true;
    }

    function saveScene(name, saved) {
        root.scene = name || "";
        root.sceneSaved = saved ? JSON.stringify(saved) : "";
        adapter.scene = root.scene;
        adapter.sceneSaved = root.sceneSaved;
        stateFile.writeAdapter();
    }

    function saveReducedMotion(on) {
        root.reducedMotion = on;
        adapter.reducedMotion = on;
        stateFile.writeAdapter();
        // Mirror the new flag to /etc/greetd/motion.json so the greeter's next
        // boot respects it too.
        Quickshell.execDetached([
            Quickshell.env("HOME") + "/.config/hypr/scripts/wallpaper",
            "sync-greeter"
        ]);
    }
}
