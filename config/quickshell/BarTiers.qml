// The tiers bar (layout B): workspaces on the left, the clock island in the
// centre, the status modules on the right -- three floating pills on a
// transparent 96 px window that reserves only the top 38 px.
//
// This file owns no shell objects: the shell (shell.qml) hands in the
// notification centre and learns about the user through signals; the morph
// triggers (island, statusPill) are aliased out because the panels grow out
// of them, and `islandHidden` / `pillHidden` come back the same way -- the
// shared-element rule lives with the panels, the pills just obey.
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects

PanelWindow {
    id: bar

    WlrLayershell.namespace: Tokens.ns.bar

    // The morph triggers, for the panels that grow out of them.
    readonly property alias island: island
    readonly property alias statusPill: statusPill
    readonly property alias dashboardPill: dashboardPill

    // The notification centre, for the bell's counter and open action.
    property var notifications: null

    // Shared-element dips: the panel that grew out of a pill is up.
    property bool islandHidden: false
    property bool pillHidden: false
    // The panel that grew out of the dashboard zone is up.
    property bool dashboardActive: false

    // The island asks for Today, the status modules ask for System (with
    // the section to open); the shell owns the panels and the trigger
    // wiring. The dashboard pill asks for the dedicated dashboard.
    signal todayRequested()
    signal systemRequested(string section)
    signal dashboardRequested()

    anchors {
        top: true
        left: true
        right: true
    }

    // Canvas for shadows and the expanded notification island (hover). Only
    // the top 38 px are reserved: windows still start below 38; the rest is
    // transparent and outside the input mask.
    implicitHeight: 180
    exclusiveZone: 38
    color: "transparent"

    // A view into the system clock. Minutes precision is enough for a bar and
    // cheaper than Seconds: QML only recomputes the bound text when the minute
    // changes, with no timer and no process of our own.
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // Clicking a workspace cell switches to it; the wheel walks relative to
    // the existing ones ("e-1"/"e+1" selectors). Hyprland's IPC dispatch
    // takes a Lua expression in 0.56 (usingLua), and the old token
    // otherwise; keeping both means the bar does not silently break if
    // Hyprland is ever started with a hyprlang config again.
    function focusWorkspace(workspaceId) {
        if (Hyprland.usingLua)
            Hyprland.dispatch("hl.dsp.focus({ workspace = " + workspaceId + " })");
        else
            Hyprland.dispatch("workspace " + workspaceId);
    }

    function focusWorkspaceRelative(delta) {
        const sel = delta > 0 ? "e+1" : "e-1";
        if (Hyprland.usingLua)
            Hyprland.dispatch("hl.dsp.focus({ workspace = \"" + sel + "\" })");
        else
            Hyprland.dispatch("workspace " + sel);
    }

    // Input follows the pills, not the window: clicks in the transparent
    // area (the shadow canvas) fall through to whatever is below. Each
    // Region tracks its item, so the mask follows the island as it grows.
    mask: Region {
        Region { item: workspacesPill }
        Region { item: island }
        Region { item: statusPill }
        Region { item: dashboardPill }
    }

    // --- Left pill: the workspaces -------------------------------------
    // Numbers in a row; the active one carries an accent capsule (30x22)
    // that slides with them (medium/standard). Empty cells show nothing;
    // hover a bg2 circle; an urgent workspace shows a neon dot. The wheel
    // walks to the previous/next existing workspace.
    Surface {
        id: workspacesPill
        level: 1
        lifted: workspacePillHover.hovered

        anchors.left: parent.left
        anchors.top: parent.top
        anchors.topMargin: Tokens.space.xs
        anchors.leftMargin: 14

        width: workspaces.implicitWidth + 16
        height: 30

        HoverHandler { id: workspacePillHover }

        // The wheel: workspace stepping over the whole pill.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton

            onWheel: function (w) {
                const step = (w.pixelDelta.y !== 0 ? w.pixelDelta.y
                            : w.angleDelta.y) > 0 ? -1 : 1;
                bar.focusWorkspaceRelative(step);
            }
        }

        // The active cell, for the capsule's slide. Through `.children`:
        // a Repeater's items are the Row's children.
        readonly property Item activeCell: {
            const kids = workspaces.children;
            for (let i = 0; i < kids.length; ++i)
                if (kids[i].modelData && kids[i].modelData.focused)
                    return kids[i];
            return null;
        }

        // The accent capsule behind the active number: x follows it.
        Rectangle {
            visible: workspacesPill.activeCell !== null
            x: workspacesPill.activeCell !== null
                ? workspaces.x + workspacesPill.activeCell.x - 4 : 0
            anchors.verticalCenter: parent.verticalCenter
            width: 30
            height: 22
            radius: 11
            color: Theme.gold

            Behavior on x {
                NumberAnimation {
                    duration: Motion.medium
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Motion.standard
                }
            }
        }

        Row {
            id: workspaces
            anchors.centerIn: parent
            spacing: 2

            Repeater {
                model: Hyprland.workspaces

                delegate: Item {
                    id: cell

                    required property var modelData

                    width: 22
                    height: 22

                    // Hover: a bg2 circle (under the capsule z-wise it does
                    // not matter: the active cell is covered by the capsule
                    // anyway).
                    Rectangle {
                        anchors.fill: parent
                        radius: 11
                        color: cell.modelData.focused
                            ? "transparent"
                            : (cellHover.containsMouse ? Theme.bg2 : "transparent")

                        Behavior on color {
                            ColorAnimation {
                                duration: Motion.fast
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Motion.standard
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: cell.modelData.id
                        color: cell.modelData.focused ? Theme.bg0 : Theme.fg1
                        font.family: "Adwaita Sans"
                        font.pixelSize: 12
                        font.bold: cell.modelData.focused
                    }

                    // Urgent: a neon dot above the number.
                    Rectangle {
                        visible: cell.modelData.urgent
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        width: 4
                        height: 4
                        radius: 2
                        color: Theme.teal
                    }

                    MouseArea {
                        id: cellHover

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: bar.focusWorkspace(cell.modelData.id)
                    }
                }
            }
        }
    }

    // --- Centre: the island --------------------------------------------
    // The arbiter decides what the island is: the clock row (media/idle),
    // the OSD (a volume/brightness change) or a notification arrival. The
    // width Behavior is the morph between them.
    Surface {
        id: island
        level: 2
        lifted: islandArea.containsMouse

        // The Today panel grows out of this surface; while its window
        // is up the island hides so there are never two copies (it comes
        // back only when the return morph has finished).
        opacity: bar.islandHidden ? 0 : 1

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Tokens.space.xs

        // Target width is computed from the content, not bound to children's
        // implicit width directly, to avoid circular bindings once the island
        // starts measuring text for the notification wing.
        // The island height: 30 when compact, grows downward on hover to show
        // the full notification. The window is 150 px tall so it fits.
        property bool expanded: false
        readonly property real islandHeight: Island.mode === "notification" && expanded
            ? expandedHeight : 30
        readonly property real expandedHeight: Math.min(170,
            30 + 6 + 16 + 4 + expandedBody.height + 10 + 26 + 10)

        // Horizontal swipe: the wing follows the fingers and fades, then
        // either leaves or springs back.
        property real swipeOffset: 0
        property real swipeAlpha: 1

        Behavior on swipeAlpha {
            NumberAnimation { duration: Motion.fast }
        }

        NumberAnimation {
            id: swipeOutAnim
            target: island
            property: "swipeOffset"
            duration: Motion.fast
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.accel
            onFinished: {
                Island.dismissCurrent();
                island.swipeOffset = 0;
                island.swipeAlpha = 1;
            }
        }

        NumberAnimation {
            id: swipeBackAnim
            target: island
            property: "swipeOffset"
            to: 0
            duration: Motion.medium
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.standard
        }

        width: targetWidth
        height: islandHeight
        radius: 15

        // Hover expands after 150 ms and collapses after 300 ms outside, so
        // moving towards the buttons does not close the panel.
        Timer {
            id: expandTimer
            interval: 150
            onTriggered: island.expanded = true
        }

        Timer {
            id: collapseTimer
            interval: 300
            onTriggered: island.expanded = false
        }
        readonly property real targetWidth: Island.mode === "osd" ? osdTarget
            : Island.mode === "notification" ? notifTarget
            : clockRow.implicitWidth + 24

        readonly property real osdTarget: Island.osdKind === "dnd"
            ? dndOsdRow.implicitWidth + 24
            : osdRow.implicitWidth + 24

        // Notification wing measurements. The body is hidden when the summary
        // takes more than 60% of the maximum wing (240 of 400 px).
        readonly property bool notifHasAvatar: Island.current !== null
            && Island.current.image !== ""
            && !Island.current.image.startsWith("image://icon/")
        readonly property string notifAvatarPath: notifHasAvatar
            ? Island.current.image : ""
        readonly property bool notifHasIcon: Island.current !== null
            && !notifHasAvatar
            && (Island.current.image !== "" || Island.current.appIcon !== "")
        readonly property string notifIconPath: {
            if (Island.current === null)
                return "";
            if (Island.current.image !== "" && !notifHasAvatar)
                return Island.current.image;
            if (Island.current.appIcon !== "")
                return Quickshell.iconPath(Island.current.appIcon);
            return "";
        }
        readonly property real notifNameWidth: Math.min(notifAppMetrics.width, 120)
        readonly property real notifSummaryWidth: Math.min(notifSummaryMetrics.width, 220)
        readonly property real notifBodyWidth: Math.min(notifBodyMetrics.width, 160)
        readonly property bool notifBodyVisible: Island.currentBody !== ""
            && notifSummaryWidth <= 240
        readonly property real notifChipWidth: Island.pendingCount > 0 ? 8 + 24 : 0

        readonly property bool notifCritical: Island.current !== null
            && Island.current.urgency === 2

        readonly property real notifTarget: Math.min(560,
            14
            + (notifHasIcon || notifHasAvatar ? 16 : notifNameWidth)
            + 8 + notifSummaryWidth
            + (notifBodyVisible ? 8 + notifBodyWidth : 0)
            + (notifCritical ? 6 + 8 : 0)
            + notifChipWidth
            + 14)

        // Growing with the media section is the island's whole trick; make
        // it a slide rather than a jump.
        Behavior on width {
            NumberAnimation {
                duration: Motion.medium
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.standard
            }
        }

        // Hover expansion: height grows with medium/decel; collapse waits
        // hoverOut + 60 ms so the cursor can leave without a fight, then
        // shrinks with base/standard (content before space).
        Behavior on height {
            SequentialAnimation {
                PauseAnimation { duration: island.expanded ? 0 : Motion.hoverOut + 60 }
                NumberAnimation {
                    duration: island.expanded ? Motion.medium : Motion.base
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: island.expanded ? Motion.decel : Motion.standard
                }
            }
        }

        // The arbiter's hover input (it pauses the notification countdown).
        Binding {
            target: Island
            property: "hovered"
            value: islandArea.containsMouse
        }

        // Declared before the rows so they sit above it: later items win
        // the click. Right-click dismisses a notification (or toggles DND on
        // the clock); middle-click clears the queue; left opens Today.
        MouseArea {
            id: islandArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            cursorShape: Qt.PointingHandCursor

            onContainsMouseChanged: {
                if (containsMouse) {
                    collapseTimer.stop();
                    expandTimer.restart();
                } else {
                    expandTimer.stop();
                    collapseTimer.restart();
                }
            }

            onClicked: function (mouse) {
                if (mouse.button === Qt.MiddleButton) {
                    Island.clearQueue();
                    return;
                }
                if (mouse.button === Qt.RightButton) {
                    if (Island.mode === "notification")
                        Island.dismissCurrent();
                    else if (bar.notifications !== null) {
                        bar.notifications.dnd = !bar.notifications.dnd;
                        Island.showDndOsd(bar.notifications.dnd);
                    }
                    return;
                }

                // Left click: the notification's default action when it has
                // one, otherwise Today.
                if (Island.mode === "notification" && Island.current !== null) {
                    const actions = Island.current.actions;
                    if (actions && actions.length > 0) {
                        bar.notifications.invokeAction(Island.current,
                            actions[0].identifier);
                        if (!Island.current.resident)
                            Island.dismissCurrent();
                        return;
                    }
                }
                bar.todayRequested();
            }
        }

        // Gestures on the notification wing: horizontal swipe dismisses,
        // vertical scroll (two fingers or the mouse wheel) walks the queue.
        SwipeTracker {
            id: swipeGesture
            anchors.fill: parent
            visible: Island.mode === "notification"

            onMoved: function (offset) {
                if (swipeGesture.axis === "x") {
                    island.swipeOffset = offset;
                    island.swipeAlpha = Math.max(0.15,
                        1 - Math.abs(offset) / (island.width * 0.6));
                }
            }

            onSwiped: function (direction, velocity) {
                const target = direction === "left" ? -island.width : island.width;
                const distance = Math.abs(target - island.swipeOffset);
                swipeOutAnim.to = target;
                swipeOutAnim.duration = Motion.release(distance, velocity,
                                                        Motion.flingSlope, 120, 240);
                swipeOutAnim.easing.bezierCurve = Motion.fling;
                swipeOutAnim.start();
            }

            onReleased: function (axis, velocity) {
                if (axis === "x") {
                    const distance = Math.abs(island.swipeOffset);
                    swipeBackAnim.duration = Motion.release(distance, velocity,
                                                             Motion.flingSlope, 160, 240);
                    swipeBackAnim.easing.bezierCurve = Motion.fling;
                    island.swipeAlpha = 1;
                    swipeBackAnim.start();
                }
            }

            onWheeled: function (direction) {
                if (direction === "up")
                    Island.back();
                else
                    Island.advance();
            }
        }

        // "88:88" measures the widest case so the island keeps one width and
        // does not breathe every minute. tnum helps when the font has it,
        // the fixed width covers the case where it does not.
        TextMetrics {
            id: timeMetrics
            font.family: "Adwaita Sans"
            font.pixelSize: 15
            font.bold: true
            font.features: ({ "tnum": 1 })
            text: "88:88"
        }

        // Notification text measurements for the target width (no circular
        // binding with the island's width).
        TextMetrics {
            id: notifAppMetrics
            font.family: "Adwaita Sans"
            font.pixelSize: 11
            text: Island.current !== null ? Island.current.appName : ""
        }

        TextMetrics {
            id: notifSummaryMetrics
            font.family: "Adwaita Sans"
            font.pixelSize: 12
            font.bold: true
            text: Island.current !== null ? Island.current.summary : ""
        }

        TextMetrics {
            id: notifBodyMetrics
            font.family: "Adwaita Sans"
            font.pixelSize: 12
            text: Island.currentBody
        }

        // The clipped content container. It is always centred and its width
        // is the target width, so as the island grows the content is revealed
        // from the centre out. Later (fase 2) the two slots will be used for
        // cross-fading between modes; for now slot A carries everything.
        Item {
            id: contentContainer
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: island.targetWidth
            height: island.islandHeight
            clip: true

            Behavior on width {
                NumberAnimation {
                    duration: Motion.medium
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Motion.standard
                }
            }

            Behavior on height {
                NumberAnimation {
                    duration: Motion.medium
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Motion.decel
                }
            }

            Item {
                id: slotA
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.horizontalCenterOffset: island.swipeOffset
                width: island.targetWidth
                height: island.islandHeight
                opacity: island.swipeAlpha

                // The normal mode: media (when a player has a track) and the clock.
                Row {
                    id: clockRow
                    visible: Island.mode === "normal"
                    anchors.centerIn: parent
                    spacing: 8

                    // The dynamic part: shows while a player has a track.
                    Media {
                        id: media
                    }

                    Rectangle {
                        visible: media.active
                        width: 1
                        height: 14
                        color: Theme.bg2
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Qt.formatDateTime(clock.date, "hh:mm")
                        width: timeMetrics.width
                        horizontalAlignment: Text.AlignHCenter
                        color: Theme.fg0
                        font.family: "Adwaita Sans"
                        font.pixelSize: 15
                        font.bold: true
                        // Tabular figures: the clock must not breathe every minute.
                        font.features: ({ "tnum": 1 })
                    }

                    // The date steps aside while the media section is up.
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !media.active
                        text: Qt.formatDateTime(clock.date, "ddd d MMM")
                        color: Theme.fg1
                        font.family: "Adwaita Sans"
                        font.pixelSize: 11
                    }

                    // DND: a bell-off glyph while it is on (neon: it wants a look).
                    Glyph {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: bar.notifications !== null && bar.notifications.dnd
                        glyph: "󰂛"
                        size: 12
                        tone: "attention"
                    }
                }

                // The OSD mode: glyph, a 120x4 bar and the percentage.
                Row {
                    id: osdRow
                    visible: Island.mode === "osd" && Island.osdKind !== "dnd"
                    anchors.centerIn: parent
                    spacing: 10

                    Glyph {
                        anchors.verticalCenter: parent.verticalCenter
                        glyph: Island.osdKind === "brightness" ? "󰃠"
                            : Island.osdMuted ? "󰖁"
                            : Island.osdValue > 0.5 ? "󰕾"
                            : Island.osdValue > 0 ? "󰖀" : "󰕿"
                        size: 15
                    }

                    Item {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 120
                        height: 4

                        Rectangle {
                            anchors.fill: parent
                            radius: 2
                            color: Qt.rgba(Theme.fg0.r, Theme.fg0.g, Theme.fg0.b, 0.10)
                        }

                        Rectangle {
                            width: parent.width * Math.max(0, Math.min(1, Island.osdValue))
                            height: parent.height
                            radius: 2
                            color: Theme.gold
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 34
                        horizontalAlignment: Text.AlignRight
                        text: Island.osdMuted ? "Muted"
                            : Math.round(Island.osdValue * 100) + "%"
                        color: Theme.fg1
                        font.family: "Adwaita Sans"
                        font.pixelSize: 11
                        font.features: ({ "tnum": 1 })
                    }
                }

                // The DND OSD: bell glyph + text.
                Row {
                    id: dndOsdRow
                    visible: Island.mode === "osd" && Island.osdKind === "dnd"
                    anchors.centerIn: parent
                    spacing: 8

                    Glyph {
                        anchors.verticalCenter: parent.verticalCenter
                        glyph: bar.notifications !== null && bar.notifications.dnd
                            ? "󰂛" : "󰂚"
                        size: 15
                        tone: bar.notifications !== null && bar.notifications.dnd
                            ? "active" : "normal"
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Island.osdText
                        color: Theme.fg0
                        font.family: "Adwaita Sans"
                        font.pixelSize: 12
                    }
                }

                // The notification mode: icon or app name, summary, body if
                // it fits, and the queue chip. Clicking opens Today.
                Row {
                    id: notifRow
                    visible: Island.mode === "notification"
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: 30
                    spacing: 8

                    // Avatar (chat image): clipped to a circle by Avatar.qml.
                    Avatar {
                        visible: island.notifHasAvatar
                        width: visible ? 16 : 0
                        height: 16
                        anchors.verticalCenter: parent.verticalCenter
                        size: 16
                        source: island.notifAvatarPath
                    }

                    Image {
                        visible: island.notifHasIcon
                        width: visible ? 16 : 0
                        height: 16
                        anchors.verticalCenter: parent.verticalCenter
                        source: island.notifIconPath
                        sourceSize.width: 16
                        sourceSize.height: 16
                        fillMode: Image.PreserveAspectFit
                    }

                    Text {
                        visible: !island.notifHasIcon && !island.notifHasAvatar
                            && Island.current !== null
                        width: visible ? island.notifNameWidth : 0
                        anchors.verticalCenter: parent.verticalCenter
                        text: Island.current !== null ? Island.current.appName : ""
                        color: Theme.fg1
                        font.family: "Adwaita Sans"
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }

                    // Critical: a 6 px red dot before the summary.
                    Rectangle {
                        visible: Island.current !== null && Island.current.urgency === 2
                        width: visible ? 6 : 0
                        height: 6
                        radius: 3
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.red
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: island.notifSummaryWidth
                        text: Island.current !== null ? Island.current.summary : ""
                        color: Theme.fg0
                        font.family: "Adwaita Sans"
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    Text {
                        visible: island.notifBodyVisible
                        width: visible ? island.notifBodyWidth : 0
                        anchors.verticalCenter: parent.verticalCenter
                        text: Island.currentBody
                        color: Theme.fg1
                        font.family: "Adwaita Sans"
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }

                    Rectangle {
                        visible: Island.pendingCount > 0 && !islandArea.containsMouse
                        width: visible ? chipLabel.implicitWidth + 10 : 0
                        height: 18
                        radius: 9
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.bg2

                        Text {
                            id: chipLabel
                            anchors.centerIn: parent
                            text: "+" + Island.pendingCount
                            color: Theme.fg1
                            font.family: "Adwaita Sans"
                            font.pixelSize: 11
                            font.features: ({ "tnum": 1 })
                        }
                    }
                }

                // The expanded detail: app name, full body (up to 4 lines) and
                // the action row. Always laid out (opacity only) so the height
                // animation has its final value from the first frame.
                Column {
                    id: notifExpanded
                    opacity: island.expanded && Island.mode === "notification" ? 1 : 0
                    anchors.top: notifRow.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 4

                    Behavior on opacity {
                        SequentialAnimation {
                            PauseAnimation {
                                duration: island.expanded && Island.mode === "notification"
                                    ? Math.round(Motion.medium * 0.4)
                                    : Motion.hoverOut
                            }
                            NumberAnimation {
                                duration: island.expanded && Island.mode === "notification"
                                    ? Motion.base
                                    : Motion.fast
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: island.expanded && Island.mode === "notification"
                                    ? Motion.decel
                                    : Motion.accel
                            }
                        }
                    }

                    Text {
                        text: Island.current !== null ? Island.current.appName : ""
                        color: Theme.fg1
                        font.family: "Adwaita Sans"
                        font.pixelSize: 12
                        width: parent.width
                        elide: Text.ElideRight
                    }

                    Text {
                        id: expandedBody
                        text: Island.currentBody
                        color: Theme.fg0
                        font.family: "Adwaita Sans"
                        font.pixelSize: 12
                        width: parent.width
                        wrapMode: Text.Wrap
                        maximumLineCount: 4
                        elide: Text.ElideRight
                    }

                    Row {
                        width: parent.width
                        height: 26
                        spacing: 8
                        layoutDirection: Qt.RightToLeft

                        Repeater {
                            model: (Island.current !== null && Island.current.actions)
                                ? Math.min(2, Island.current.actions.length) : 0

                            delegate: Pressable {
                                id: actionButton
                                width: actionLabel.implicitWidth + 16
                                height: 26
                                pressScale: 1.0

                                readonly property var action: Island.current !== null
                                    ? Island.current.actions[index] : null

                                onClicked: {
                                    if (actionButton.action === null)
                                        return;
                                    bar.notifications.invokeAction(Island.current,
                                        actionButton.action.identifier);
                                    if (!Island.current.resident)
                                        Island.dismissCurrent();
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: height / 2
                                    color: Qt.rgba(Theme.bg2.r, Theme.bg2.g, Theme.bg2.b,
                                        actionButton.hovered ? 0.90 : 0.60)
                                }

                                Text {
                                    id: actionLabel
                                    anchors.centerIn: parent
                                    text: actionButton.action !== null
                                        ? actionButton.action.text : ""
                                    color: Theme.fg0
                                    font.family: "Adwaita Sans"
                                    font.pixelSize: 12
                                }
                            }
                        }

                        Pressable {
                            visible: Island.current !== null && Island.current.actions
                                && Island.current.actions.length > 2
                            width: moreLabel.implicitWidth + 16
                            height: 26
                            pressScale: 1.0
                            onClicked: bar.todayRequested()

                            Text {
                                id: moreLabel
                                anchors.centerIn: parent
                                text: "More…"
                                color: Theme.fg1
                                font.family: "Adwaita Sans"
                                font.pixelSize: 12
                            }
                        }

                        Pressable {
                            width: dismissLabel.implicitWidth + 16
                            height: 26
                            pressScale: 1.0
                            onClicked: Island.dismissCurrent()

                            Text {
                                id: dismissLabel
                                anchors.centerIn: parent
                                text: "Dismiss"
                                color: Theme.fg1
                                font.family: "Adwaita Sans"
                                font.pixelSize: 12
                            }
                        }
                    }
                }
            }

            // Slot B is reserved for cross-fading content in later phases.
            Item {
                id: slotB
                anchors.centerIn: parent
                width: island.targetWidth
                height: 30
                visible: false
            }
        }

        // Critical notifications: a red border while they are on screen
        // (red keeps its single meaning: something is wrong).
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.width: 1
            border.color: Theme.red
            visible: Island.current !== null && Island.current.urgency === 2
        }

        // The dismiss button, on hover: it sits above the wing's right edge
        // and does not change the island width.
        Pressable {
            id: dismissButton
            visible: islandArea.containsMouse && Island.mode === "notification"
            width: 24
            height: 24
            pressScale: 1.0
            anchors.right: parent.right
            anchors.rightMargin: 2
            anchors.top: parent.top
            anchors.topMargin: 3

            onClicked: Island.dismissCurrent()

            Glyph {
                anchors.centerIn: parent
                glyph: "󰅖"
                size: 12
                tone: dismissButton.hovered ? "hover" : "normal"
            }
        }

        // The countdown line: 2px fg1 at 40% along the base (not accent: it
        // is time, not an active state).
        Rectangle {
            visible: Island.mode === "notification"
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.right: parent.right
            anchors.rightMargin: 14
            height: 2
            radius: 1
            color: Qt.rgba(Theme.fg1.r, Theme.fg1.g, Theme.fg1.b, 0.40)
            clip: true

            Rectangle {
                width: parent.width * (Island.hasProgress
                    ? Math.max(0, Math.min(1, Island.progressValue / 100))
                    : Island.progress)
                height: parent.height
                radius: 1
                color: Island.hasProgress ? Theme.gold : Theme.fg1
            }
        }

        // The unread dot: neon, until the notifications are read.
        Rectangle {
            visible: bar.notifications !== null && bar.notifications.unreadCount > 0
                && Island.mode === "normal"
            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.top: parent.top
            anchors.topMargin: 4
            width: 6
            height: 6
            radius: 3
            color: Theme.teal

            Behavior on opacity {
                NumberAnimation {
                    duration: Motion.fade
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Motion.standard
                }
            }
        }
    }

    // --- Right: the status + dashboard pill ------------------------------
    // One surface for the system controls: the resource alert when it
    // applies, volume, wifi, bluetooth (only when on), battery, the tray
    // icons when an application registers one, and the dashboard, separated
    // by a hairline so the chart reads as its own control. The pill's padding
    // opens System; the chart opens the dashboard.
    Surface {
        id: statusPill
        level: 1
        lifted: statusPillHover.hovered

        opacity: bar.pillHidden ? 0 : 1

        Behavior on width {
            NumberAnimation {
                duration: Motion.medium
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.standard
            }
        }

        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: Tokens.space.xs
        anchors.rightMargin: 14

        width: content.implicitWidth + 24
        height: 30

        HoverHandler { id: statusPillHover }

        // The pill's padding is clickable too: it opens System. The chart
        // sits above, so its own click wins there.
        MouseArea {
            anchors.fill: parent
            z: -1
            cursorShape: Qt.PointingHandCursor
            onClicked: bar.systemRequested("")
        }

        Row {
            id: content
            anchors.centerIn: parent
            spacing: 0

            Row {
                id: modules
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12

                // Tray icons lead the pill: the applications' own icons sit
                // to the left of the system controls. The slot collapses to
                // zero when no application registers one, so the pill only
                // grows when there is something to show.
                Item {
                    id: traySlot

                    visible: tray.implicitWidth > 0
                    width: tray.implicitWidth
                    height: 30

                    Tray {
                        id: tray
                        anchors.centerIn: parent
                    }
                }

                ResourcesAlert {
                    onActivated: function (section) { bar.systemRequested(section); }
                }

                Volume {
                    onActivated: function (section) { bar.systemRequested(section); }
                }

                Wifi {
                    onActivated: function (section) { bar.systemRequested(section); }
                }

                Bluetooth {
                    onActivated: function (section) { bar.systemRequested(section); }
                }

                Battery {
                    onActivated: function (section) { bar.systemRequested(section); }
                }

            }

            // The hairline between the status modules and the dashboard.
            Item {
                width: 1 + 2 * 9
                height: 30
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    anchors.centerIn: parent
                    width: 1
                    height: 14
                    color: Qt.rgba(Theme.fg0.r, Theme.fg0.g, Theme.fg0.b, 0.12)
                }
            }

            // The dashboard zone: its own hover and click inside the shared
            // pill. It stays visible (and turns gold) while the panel is up:
            // the panel does not duplicate it, so there is no shared-element
            // hole to fill.
            Item {
                id: dashboardPill
                anchors.verticalCenter: parent.verticalCenter
                width: 26
                height: 30

                HoverHandler { id: dashboardHover }

                MouseArea {
                    anchors.fill: parent
                    z: -1
                    cursorShape: Qt.PointingHandCursor
                    onClicked: bar.dashboardRequested()
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: 22
                    height: 22
                    radius: 11
                    color: dashboardHover.hovered
                        ? Qt.rgba(Theme.bg2.r, Theme.bg2.g, Theme.bg2.b, 0.8)
                        : "transparent"
                }

                Text {
                    anchors.centerIn: parent
                    text: "󰄨"
                    color: dashboardHover.hovered || bar.dashboardActive
                        ? Theme.gold : Theme.fg1
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 14
                }
            }
        }
    }


}
