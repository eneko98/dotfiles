// The bar. This is the root of the Quickshell config: Quickshell looks for
// ~/.config/quickshell/shell.qml and runs it.
//
// The surface is a transparent 96 px window that reserves only the top 38 px
// (exclusiveZone): three floating pills sit in the top strip -- workspaces on
// the left, the clock island in the centre, the status modules on the right --
// and the extra height below them is where their drop shadows live. An input
// mask (Region over the three pills) lets clicks fall through the transparent
// rest, so a taller window changes nothing about hit-testing. The pills are
// Surface items (Tokens elevation); the wallpaper shows between them.
//
// The island is the seed of the dynamic island: it already reacts to hover, and
// the control centre will open from it. It is deliberately the only "chrome" in
// the middle, so the bar reads as three things instead of a row of widgets.
//
// QML is declarative: you describe a tree (a window containing a row containing
// one item per workspace) and bind properties to live data. Quickshell supplies
// the Wayland pieces (PanelWindow, the Hyprland module); QtQuick supplies the
// visuals (Rectangle, Text, Row).
//
// Colours come from Theme.qml, which scripts/gen-theme.py generates from
// config/hypr/theme.lua. There is no hex value in this file.

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick

ShellRoot {
    id: root

    // Singletons cannot see each other by name (measured), so the shell
    // wires the persisted reduced-motion switch into Motion once, and the
    // `bar` IPC keeps them in step on changes. A persisted scene is applied
    // here too: the shell is the side that owns the effects.
    Component.onCompleted: {
        Motion.reduced = Config.reducedMotion;
        if (Config.scene !== "") {
            Scenes.active = Config.scene;
            root.applyScene(Config.scene, true);
        }
    }

    // A view into the system clock. Minutes precision is enough for a bar and
    // cheaper than Seconds: QML only recomputes the bound text when the minute
    // changes, with no timer and no process of our own.
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // Clicking a workspace circle switches to it. Hyprland's IPC dispatch takes
    // a Lua expression in 0.56 (usingLua), and the old token otherwise; keeping
    // both means the bar does not silently break if Hyprland is ever started
    // with a hyprlang config again.
    function focusWorkspace(workspaceId) {
        if (Hyprland.usingLua)
            Hyprland.dispatch("hl.dsp.focus({ workspace = " + workspaceId + " })");
        else
            Hyprland.dispatch("workspace " + workspaceId);
    }

    // The island opens Today, centred under itself: the panel's right margin
    // is half of what is left of the screen once the panel is out. The island
    // is also the morph trigger, and it hides while the panel is up (the
    // panel IS the island, expanded) -- it comes back when the window, and
    // with it the return morph, is gone.
    function openToday() {
        if (barLoader.item === null)
            return;
        notifications.markAllRead();
        todayPanel.trigger = barLoader.item.island;
        // The bar's width, not the popup's: a hidden popup measures 0 and
        // the centring goes negative -- off-screen to the right (measured).
        todayPanel.rightMargin = (barLoader.item.width - todayPanel.panelWidth) / 2;
        todayPanel.visible = true;
    }

    // The status pill opens System, its right edge aligned with the pill's.
    function openSystem(section) {
        if (barLoader.item === null)
            return;
        const pill = barLoader.item.statusPill;
        // With the bar hidden (Cine) there is no trigger to grow from; the
        // panel fades in at the same right edge instead.
        systemPanel.trigger = Scenes.active === "cine" ? null : pill;
        // The bar window is unmapped in Cine, so use its fixed right gap
        // instead of measuring a hidden layout.
        systemPanel.rightMargin = Scenes.active === "cine"
            ? 28
            : barLoader.item.width - pill.x - pill.width + 14;
        systemPanel.section = section || "";
        systemPanel.visible = true;
    }

    // The dedicated system dashboard, hanging from its pill on the right.
    function openDashboard(fromPill) {
        if (barLoader.item === null)
            return;
        if (systemPanel.visible)
            systemPanel.close();
        // The dashboard pill lives inside the status pill, so its own x is
        // relative to that surface, not to the bar. Use the status pill for
        // the right edge and the dashboard pill only as the morph trigger.
        const status = barLoader.item.statusPill;
        dashboardPanel.trigger = fromPill ? barLoader.item.dashboardPill : null;
        dashboardPanel.rightMargin = fromPill
            ? barLoader.item.width - status.x - status.width + 14
            : 28;
        dashboardPanel.visible = true;
    }

    // The workspace carousel, centred. It has no trigger: the gesture and the
    // keybind open it from anywhere, so it fades in place.
    function openOverview() {
        if (barLoader.item === null)
            return;
        overview.rightMargin = (barLoader.item.width - overview.panelWidth) / 2;
        overview.visible = true;
    }

    // The launcher hangs from the island, centred, instead of floating in the
    // middle of the screen.
    function openLauncher() {
        launcher.trigger = barLoader.item.island;
        launcher.rightMargin = (barLoader.item.width - launcher.panelWidth) / 2;
        launcher.open();
    }

    // The wallpaper picker does the same.
    function openWallpaperPicker() {
        wallpaperPicker.trigger = barLoader.item.island;
        wallpaperPicker.rightMargin = (barLoader.item.width - wallpaperPicker.panelWidth) / 2;
        wallpaperPicker.open();
    }

    // --- Scenes -----------------------------------------------------------
    // The shell applies the effects; the singleton only holds the name and
    // the definitions. The previous value of each knob is saved before it is
    // touched, and that saved value is what leaving restores.
    property var sceneSaved: ({})
    // The dim_inactive value restoreScene() just wrote back. A switch straight
    // into another scene reuses it instead of re-reading: the restore and the
    // read are two separate processes, and the read could otherwise catch the
    // outgoing scene's value before the restore lands.
    property var dimOriginal: null
    property string pendingScene: ""

    function setDimInactive(value) {
        Quickshell.execDetached([
            "hyprctl", "eval",
            "hl.config({ decoration = { dim_inactive = "
                + (value ? "true" : "false") + " } })"
        ]);
    }

    // The scene's own effects. Split from applyScene() because entering has to
    // know the real dim_inactive first: saving an assumed `true` turns a
    // deliberate `false` into the scene's value for good.
    function commitScene(name) {
        const def = Scenes.definitions[name];
        if (!def)
            return;

        notifications.dnd = def.dnd;
        Caffeine.active = def.caffeine;
        root.setDimInactive(def.dimInactive);

        if (def.spotify)
            Quickshell.execDetached(["sh", "-c",
                "$HOME/.config/hypr/scripts/spotify-toggle"]);

        Config.saveScene(name, root.sceneSaved);
    }

    function applyScene(name, fromDisk) {
        const def = Scenes.definitions[name];
        if (!def)
            return;

        if (fromDisk) {
            try {
                root.sceneSaved = Config.sceneSaved !== ""
                    ? JSON.parse(Config.sceneSaved) : {};
            } catch (e) {
                root.sceneSaved = {};
            }
            root.commitScene(name);
            return;
        }

        const carry = root.dimOriginal;
        root.dimOriginal = null;
        if (carry !== null) {
            root.sceneSaved = {
                dnd: notifications.dnd,
                caffeine: Caffeine.active,
                dimInactive: carry
            };
            root.commitScene(name);
            return;
        }

        // hyprctl getoption reports the live value under the Lua parser too
        // (`bool: true` / `set: true`). Anything else falls back to the old
        // assumed `true` rather than skipping the save.
        root.pendingScene = name;
        dimRead.running = true;
    }

    function restoreScene() {
        const saved = root.sceneSaved;
        if (saved.dnd !== undefined)
            notifications.dnd = saved.dnd;
        if (saved.caffeine !== undefined)
            Caffeine.active = saved.caffeine;

        const dim = saved.dimInactive !== undefined ? saved.dimInactive : true;
        root.setDimInactive(dim);
        // A leave that is the first half of a switch is consumed by
        // applyScene() in this same event-loop turn; a real exit clears it.
        root.dimOriginal = dim;
        Qt.callLater(function () { root.dimOriginal = null; });

        root.sceneSaved = ({});
        Config.saveScene("", null);
    }

    // The bar, extracted to a layout component so the selector (the `bar`
    // IPC, Config.barLayout) can swap it without touching the rest. Only
    // tiers exists today; the binding is already layout-shaped.
    Loader {
        id: barLoader

        source: Config.barLayout === "island" ? "BarIsland.qml"
            : Config.barLayout === "frame" ? "BarFrame.qml"
            : "BarTiers.qml"
    }

    Binding {
        target: barLoader.item
        property: "notifications"
        value: notifications
    }

    Binding {
        target: barLoader.item
        property: "islandHidden"
        value: todayPanel.visible && todayPanel.trigger !== null
            && barLoader.item !== null && todayPanel.trigger === barLoader.item.island
    }

    Binding {
        target: barLoader.item
        property: "pillHidden"
        value: systemPanel.visible && systemPanel.trigger !== null
            && barLoader.item !== null && systemPanel.trigger === barLoader.item.statusPill
    }

    Binding {
        target: barLoader.item
        property: "dashboardActive"
        value: dashboardPanel.visible && dashboardPanel.trigger !== null
            && barLoader.item !== null
            && dashboardPanel.trigger === barLoader.item.dashboardPill
    }

    // Cine hides the bar: the PanelWindow unmaps, so its exclusive zone goes
    // with it and the video gets the full screen. The System panel is a
    // separate window and can still be opened to leave the scene.
    Binding {
        target: barLoader.item
        property: "visible"
        value: Scenes.active !== "cine"
    }

    // The bar asks; the shell owns the panels.
    Connections {
        target: barLoader.item

        function onTodayRequested() {
            root.openToday();
        }

        function onSystemRequested(section) {
            root.openSystem(section);
        }

        function onDashboardRequested() {
            root.openDashboard(true);
        }
    }

    // The island's notification lifecycle: a notification seen for one second
    // or dismissed off the island counts as read (it stays in the history).
    Connections {
        target: Island

        function onRead(id) {
            notifications.markRead(id);
        }

        function onDismissed(id) {
            notifications.markRead(id);
        }
    }

    // Activities that fail or last long leave a notification in the history
    // (and, if not in DND, in the island). Timers always do. When paru wraps
    // the run, the pacman activity is silent: the paru one reports at the end.
    Connections {
        target: Island

        function onActivityEnded(id, label, ok, ms) {
            if (id === "pacman" && Island.activities["paru"] !== undefined)
                return;
            if (!ok || ms > 60000 || id === "timer") {
                const summary = id === "timer" ? "Timer: " + label
                    : ok ? label + " finished" : label + " failed";
                const body = id === "timer" ? "Done"
                    : ok ? "Took " + Math.round(ms / 1000) + " s"
                    : "Exit status non-zero";
                const args = ["notify-send", "-a", "Activity",
                    "-i", ok ? "dialog-information" : "dialog-error"];
                if (!ok)
                    args.push("-u", "critical");
                args.push(summary, body);
                Quickshell.execDetached(args);
            }
        }
    }

    // Scenes: the singleton holds the name; the shell applies and reverts.
    Connections {
        target: Scenes

        function onEnter(name) {
            root.applyScene(name, false);
        }

        function onLeave() {
            root.restoreScene();
        }
    }

    // Reads decoration:dim_inactive before a scene overwrites it. Under the
    // Lua parser the value is still readable: `bool: true` plus `set: true`.
    Process {
        id: dimRead

        command: ["hyprctl", "getoption", "decoration:dim_inactive"]

        stdout: StdioCollector {
            onStreamFinished: {
                if (root.pendingScene === "")
                    return;
                root.sceneSaved = {
                    dnd: notifications.dnd,
                    caffeine: Caffeine.active,
                    // An unreadable answer keeps the old assumed `true`.
                    dimInactive: text.indexOf("bool: false") < 0
                };
                root.commitScene(root.pendingScene);
                root.pendingScene = "";
            }
        }
    }

    // The state file is read asynchronously; apply the persisted scene when
    // it has arrived, not at Component.onCompleted.
    Connections {
        target: Config

        function onLoaded() {
            if (Config.scene !== "" && Scenes.active !== Config.scene) {
                Scenes.active = Config.scene;
                root.applyScene(Config.scene, true);
            }
        }
    }

    // With Today open, arrivals go straight to the list and count as read.
    Binding {
        target: notifications
        property: "todayOpen"
        value: todayPanel.visible
    }

    // The island's live inputs (the old bottom bubble's watchers, retired):
    // volume changes through Pipewire's default sink -- the same node the
    // media keys and the sliders change -- and brightness through the
    // backlight sysfs file, which catches the keys and external writes.
    // `armed` waits after startup so the first bindings do not flash an OSD
    // nobody asked for. Singletons cannot reference each other here, so
    // these producers live in the shell and push into Island.
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var sinkAudio: sink ? sink.audio : null
    readonly property real sinkVolume: sinkAudio ? sinkAudio.volume : 0
    readonly property bool sinkMuted: sinkAudio ? sinkAudio.muted : false
    property bool islandArmed: false
    property int lastBrightness: -1

    Timer {
        interval: 1200
        running: true
        onTriggered: root.islandArmed = true
    }

    onSinkVolumeChanged: {
        if (islandArmed)
            Island.showOsd("volume", sinkVolume, sinkMuted);
    }

    onSinkMutedChanged: {
        if (islandArmed)
            Island.showOsd("volume", sinkVolume, sinkMuted);
    }

    // The device node is the laptop's; a second panel needs a lookup here.
    FileView {
        id: maxFile
        path: "/sys/class/backlight/amdgpu_bl1/max_brightness"
        blockLoading: true
    }

    readonly property int maxBrightness: parseInt(maxFile.text()) || 0

    FileView {
        id: brightnessFile
        path: "/sys/class/backlight/amdgpu_bl1/brightness"
        watchChanges: true
        printErrors: false

        onFileChanged: reload()

        onTextChanged: {
            const raw = parseInt(text());
            if (isNaN(raw) || root.maxBrightness <= 0)
                return;

            const pct = Math.round(raw / root.maxBrightness * 100);
            Brightness.percent = pct;
            if (!root.islandArmed || pct === root.lastBrightness)
                return;
            root.lastBrightness = pct;
            Island.showOsd("brightness", pct / 100, false);
        }
    }

    // The OSD never shows while the System panel is up: it owns those
    // controls on screen.
    Binding {
        target: Island
        property: "systemPanelOpen"
        value: systemPanel.visible
    }

    // The two panels of the new layout: the island opens Today, the status
    // pill opens System. The old bottom OSD bubble is retired: its watchers
    // moved up into the island's producers.
    TodayPanel {
        id: todayPanel
        notifications: notifications
        panelName: "today"
    }

    SystemPanel {
        id: systemPanel
        panelName: "system"
    }

    DashboardPanel {
        id: dashboardPanel
        panelName: "dashboard"
    }

    Overview {
        id: overview
        panelName: "overview"
    }

    // The notification server, toasts and history. mako's service is disabled
    // while this owns org.freedesktop.Notifications.
    NotificationCenter {
        id: notifications
    }

    // Long-running ALPM transactions as island activities. The pacman hooks
    // write /run/dotfiles/pacman.json; this tails the log for per-package
    // progress. Nothing runs while there is no transaction.
    PacmanActivity {
        id: pacmanActivity
    }

    // The measurement HUD, passive and off by default.
    Hud {
        id: hud
    }

    // A countdown published as an activity: `qs ipc call activity timer`.
    ActivityTimer {
        id: activityTimer
    }

    // The application launcher, opened by SUPER + Space through the IPC handler
    // below (config/hypr/scripts/launcher calls `qs ipc call launcher toggle`).
    Launcher {
        id: launcher
        panelName: "launcher"
    }

    IpcHandler {
        target: "launcher"

        function toggle(): void {
            if (launcher.visible)
                launcher.close();
            else
                root.openLauncher();
        }

        function close(): void {
            launcher.close();
        }

        function query(text: string): void {
            launcher.setQuery(text);
        }
    }

    // The wallpaper picker, opened by SUPER + W through the wallpaper script
    // (`qs ipc call wallpaper toggle`).
    WallpaperPicker {
        id: wallpaperPicker
        panelName: "wallpaper"
    }

    IpcHandler {
        target: "wallpaper"

        function toggle(): void {
            if (wallpaperPicker.visible)
                wallpaperPicker.close();
            else
                root.openWallpaperPicker();
        }

        function close(): void {
            wallpaperPicker.close();
        }
    }

    // The island's panel, so it can be opened from a script (screenshots,
    // future keybinds) without clicking the island. Formerly the
    // controlcentre target: the control centre is Today now.
    IpcHandler {
        target: "controlcenter"

        function toggle(): void {
            if (todayPanel.visible)
                todayPanel.close();
            else
                root.openToday();
        }

        function close(): void {
            todayPanel.close();
        }
    }

    // The status pill's panel; SUPER+N goes here.
    IpcHandler {
        target: "system"

        function toggle(): void {
            if (systemPanel.visible)
                systemPanel.close();
            else
                root.openSystem("");
        }

        function close(): void {
            systemPanel.close();
        }
    }

    // The dedicated dashboard, opened from Resources' link or a script
    // (`qs ipc call dashboard toggle`).
    IpcHandler {
        target: "dashboard"

        function toggle(): void {
            if (dashboardPanel.visible)
                dashboardPanel.close();
            else
                root.openDashboard(true);
        }

        function close(): void {
            dashboardPanel.close();
        }
    }

    // Scenes: toggle by name, or leave whichever is active.
    IpcHandler {
        target: "scene"

        function toggle(name: string): void {
            Scenes.toggle(name);
        }

        function clear(): void {
            Scenes.clear();
        }

        function state(): string {
            return Scenes.active;
        }
    }

    // Long-running activities: any script can publish one to the island.
    // `progress` is the common case; `progressText` adds a label such as
    // "23/41" without a second call.
    IpcHandler {
        target: "activity"

        function start(id: string, label: string): void {
            Island.activityStart(id, label);
        }

        function progress(id: string, value: real): void {
            Island.activityProgress(id, value, "");
        }

        function progressText(id: string, value: real, text: string): void {
            Island.activityProgress(id, value, text);
        }

        function end(id: string, ok: bool): void {
            Island.activityEnd(id, ok);
        }

        function timer(label: string, seconds: int): void {
            activityTimer.start(label, seconds);
        }
    }

    // The workspace carousel, opened by the three-finger vertical gesture or
    // SUPER+Tab (`qs ipc call overview toggle`).
    IpcHandler {
        target: "overview"

        function toggle(): void {
            if (overview.visible)
                overview.close();
            else
                root.openOverview();
        }

        function close(): void {
            overview.close();
        }

        function next(): void {
            overview.step(1);
        }

        function prev(): void {
            overview.step(-1);
        }

        function select(): void {
            overview.select();
        }

        function state(): string {
            return overview.current + "/" + overview.count;
        }
    }

    // The bar itself: layout selector, panel toggles, reduced motion
    // (brief 17.2). setLayout refuses the layouts that are not built yet;
    // the Loader's source binding is already ready for them.
    IpcHandler {
        target: "bar"

        function setLayout(layout: string): void {
            if (layout !== "tiers") {
                console.warn("bar: layout not built yet:", layout);
                return;
            }
            Config.setLayout(layout);
        }

        function toggleToday(): void {
            if (todayPanel.visible)
                todayPanel.close();
            else
                root.openToday();
        }

        function toggleSystem(section: string): void {
            if (systemPanel.visible && (section === "" || section === undefined)) {
                systemPanel.close();
                return;
            }
            root.openSystem(section);
        }

        function openSystem(section: string): void {
            if (!systemPanel.visible)
                root.openSystem(section);
        }

        function closeSystem(): void {
            systemPanel.close();
        }

        function dnd(value: string): void {
            notifications.dnd = value === "true";
            Island.showDndOsd(notifications.dnd);
        }

        function expand(value: string): void {
            if (barLoader.item !== null)
                barLoader.item.island.expanded = value === "true";
        }

        function notifNext(): void {
            Island.advance();
        }

        function notifPrev(): void {
            Island.back();
        }

        function reducedMotion(value: string): void {
            const on = value === "true";
            Motion.reduced = on;
            Config.saveReducedMotion(on);
        }

        function hud(value: string): void {
            if (value === "toggle")
                Config.saveHud(!Config.hud);
            else
                Config.saveHud(value === "true");
        }

        // Frame stats as JSON, for scripts/measure: an A/B run samples this
        // once a second without needing the HUD painted on screen.
        function perfStats(): string {
            return JSON.stringify(Perf.frameStats);
        }
    }

    // Lyrics: the System toggle lives here once the island uses it, and this
    // is also how a line is checked without a screenshot.
    IpcHandler {
        target: "lyrics"

        function state(): string {
            return "playing=" + Lyrics.playing
                + " enabled=" + Lyrics.enabled
                + " lines=" + Lyrics.lines.length
                + " index=" + Lyrics.index
                + " current='" + Lyrics.current + "'";
        }

        function enabled(value: string): void {
            Lyrics.enabled = value === "true";
        }
    }
}
