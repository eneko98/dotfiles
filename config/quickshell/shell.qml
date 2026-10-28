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
    // `bar` IPC keeps them in step on changes.
    Component.onCompleted: Motion.reduced = Config.reducedMotion

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
        systemPanel.trigger = pill;
        systemPanel.rightMargin = barLoader.item.width - pill.x - pill.width + 14;
        systemPanel.section = section || "";
        systemPanel.visible = true;
    }

    // The dedicated system dashboard (Resources' link and the `dashboard`
    // IPC). Centred, so the margin is whatever is left on both sides.
    function openDashboard() {
        if (barLoader.item === null)
            return;
        if (systemPanel.visible)
            systemPanel.close();
        dashboardPanel.rightMargin = (barLoader.item.width - dashboardPanel.panelWidth) / 2;
        dashboardPanel.visible = true;
    }

    // The launcher is centred too; the panel width is fixed by Launcher.qml.
    function openLauncher() {
        launcher.rightMargin = (barLoader.item.width - launcher.panelWidth) / 2;
        launcher.open();
    }

    // The wallpaper picker is centred for the same reason.
    function openWallpaperPicker() {
        wallpaperPicker.rightMargin = (barLoader.item.width - wallpaperPicker.panelWidth) / 2;
        wallpaperPicker.open();
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

    // The bar asks; the shell owns the panels.
    Connections {
        target: barLoader.item

        function onTodayRequested() {
            root.openToday();
        }

        function onSystemRequested(section) {
            root.openSystem(section);
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
    }

    SystemPanel {
        id: systemPanel
        onDashboardRequested: root.openDashboard()
    }

    DashboardPanel {
        id: dashboardPanel
    }

    // The notification server, toasts and history. mako's service is disabled
    // while this owns org.freedesktop.Notifications.
    NotificationCenter {
        id: notifications
    }

    // The application launcher, opened by SUPER + Space through the IPC handler
    // below (config/hypr/scripts/launcher calls `qs ipc call launcher toggle`).
    Launcher {
        id: launcher
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
    }

    // The wallpaper picker, opened by SUPER + W through the wallpaper script
    // (`qs ipc call wallpaper toggle`).
    WallpaperPicker {
        id: wallpaperPicker
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
                root.openDashboard();
        }

        function close(): void {
            dashboardPanel.close();
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
    }
}
