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
import QtQuick

PanelWindow {
    id: bar

    // The morph triggers, for the panels that grow out of them.
    readonly property alias island: island
    readonly property alias statusPill: statusPill

    // The notification centre, for the bell's counter and open action.
    property var notifications: null

    // Shared-element dips: the panel that grew out of a pill is up.
    property bool islandHidden: false
    property bool pillHidden: false

    // The island asks for Today, the status modules ask for System (with
    // the section to open); the shell owns the panels and the trigger
    // wiring.
    signal todayRequested()
    signal systemRequested(string section)

    anchors {
        top: true
        left: true
        right: true
    }

    // 96 px of canvas for shadows and (later) the expanded island, but
    // only the top 38 px are reserved: windows still start below 38.
    implicitHeight: 96
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
                            ColorAnimation { duration: Motion.fast }
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

        Behavior on opacity {
            NumberAnimation { duration: Motion.fade }
        }

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Tokens.space.xs

        // Target width is computed from the content, not bound to children's
        // implicit width directly, to avoid circular bindings once the island
        // starts measuring text for the notification wing.
        width: targetWidth
        height: 30
        readonly property real targetWidth: Island.mode === "osd" ? osdTarget
            : Island.mode === "notification" ? notifTarget
            : clockRow.implicitWidth + 24

        readonly property real osdTarget: osdRow.implicitWidth + 24

        // Notification wing measurements. The body is hidden when the summary
        // takes more than 60% of the maximum wing (240 of 400 px).
        readonly property bool notifHasIcon: Island.current !== null
            && (Island.current.image !== "" || Island.current.appIcon !== "")
        readonly property string notifIconPath: {
            if (Island.current === null)
                return "";
            if (Island.current.image !== "")
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

        readonly property real notifTarget: Math.min(560,
            14
            + (notifHasIcon ? 16 : notifNameWidth)
            + 8 + notifSummaryWidth
            + (notifBodyVisible ? 8 + notifBodyWidth : 0)
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

        // The arbiter's hover input (it pauses the notification countdown).
        Binding {
            target: Island
            property: "hovered"
            value: islandArea.containsMouse
        }

        // Declared before the rows so they sit above it: later items win
        // the click.
        MouseArea {
            id: islandArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: bar.todayRequested()
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
            anchors.centerIn: parent
            width: island.targetWidth
            height: 30
            clip: true

            Behavior on width {
                NumberAnimation {
                    duration: Motion.medium
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Motion.standard
                }
            }

            Item {
                id: slotA
                anchors.centerIn: parent
                width: island.targetWidth
                height: 30

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
                }

                // The OSD mode: glyph, a 120x4 bar and the percentage.
                Row {
                    id: osdRow
                    visible: Island.mode === "osd"
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

                // The notification mode: icon or app name, summary, body if
                // it fits, and the queue chip. Clicking opens Today.
                Row {
                    id: notifRow
                    visible: Island.mode === "notification"
                    anchors.centerIn: parent
                    spacing: 8

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
                        visible: !island.notifHasIcon && Island.current !== null
                        width: visible ? island.notifNameWidth : 0
                        anchors.verticalCenter: parent.verticalCenter
                        text: Island.current !== null ? Island.current.appName : ""
                        color: Theme.fg1
                        font.family: "Adwaita Sans"
                        font.pixelSize: 11
                        elide: Text.ElideRight
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
                        visible: Island.pendingCount > 0
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
                width: parent.width * Island.progress
                height: parent.height
                radius: 1
                color: Theme.fg1
            }
        }

        // The unread dot: neon, until Today opens.
        Rectangle {
            visible: Island.unread && Island.mode === "normal"
            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.top: parent.top
            anchors.topMargin: 4
            width: 6
            height: 6
            radius: 3
            color: Theme.teal

            Behavior on opacity {
                NumberAnimation { duration: Motion.fade }
            }
        }
    }

    // --- Right: the status pill + the tray pill -------------------------
    // Status: the resource alert when it applies, then volume, wifi,
    // bluetooth (only when on) and battery -- no SSID, no volume %, no
    // power glyph: the machine's controls live in the System panel. The
    // tray is its own pill, only when there are icons.
    Surface {
        id: statusPill
        level: 1
        lifted: statusPillHover.hovered

        opacity: bar.pillHidden ? 0 : 1

        Behavior on opacity {
            NumberAnimation { duration: Motion.fade }
        }

        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: Tokens.space.xs
        anchors.rightMargin: trayPill.visible ? 14 + trayPill.width + 8 : 14

        width: modules.implicitWidth + 28
        height: 30

        HoverHandler { id: statusPillHover }

        // The pill's padding is clickable too: it opens System.
        MouseArea {
            anchors.fill: parent
            z: -1
            cursorShape: Qt.PointingHandCursor
            onClicked: bar.systemRequested("")
        }

        Row {
            id: modules
            anchors.centerIn: parent
            spacing: 12

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
    }

    Surface {
        id: trayPill
        level: 1

        visible: tray.implicitWidth > 0
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: Tokens.space.xs
        anchors.rightMargin: 14

        width: tray.implicitWidth + 16
        height: 30

        Tray {
            id: tray
            anchors.centerIn: parent
        }
    }
}
