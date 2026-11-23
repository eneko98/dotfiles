// A desktop widget: a card floating over the wallpaper.
//
// The window is a Background layer surface, so tiled windows go above it and
// the wallpaper is all that shows around it. Only the card takes input: the
// mask is its own region, the same trick as the bar's.
//
// Position: each widget id has an x/y pair in bar-state.json; -1 means "never
// dragged", and the default corner (computed from the screen) is used until
// the user moves it. Press-and-move drags the card -- free while dragging,
// snapped to an 8 px grid on release. A release without movement is a click,
// so the drag area doubles as the card's button.
//
// Sizing: cardW/cardH are BASE units (the content is authored in them); the
// user's zoom (also persisted) scales the card and the content as one block,
// so text rasterizes at the final size and stays crisp. The caller may bind
// cardW to an animated value -- the card has Behaviors for width and height.
import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    property string widgetId: ""
    // The corner the widget falls to when it has never been dragged.
    property bool defaultRight: true
    property bool defaultBottom: true
    property real defaultMargin: 24
    // Scenes hide the widgets through this; the position never moves.
    property bool forceHidden: false

    // Base size. -1 is not a thing here: a widget without a size is a bug,
    // the 1x1 lesson.
    property real cardW: 0
    property real cardH: 0

    signal clicked()

    // The user's zoom, persisted per widget. The live value goes through an
    // offset so the resize drag never writes into a binding (the lesson of
    // every `running:` property so far).
    readonly property real zoom: widgetId === "fetch"
        ? Config.fetchScale : Config.vinylScale
    property real zoomD: 0
    readonly property real liveScale: Math.max(0.7,
        Math.min(1.6, root.zoom + root.zoomD))

    // The caller's children land in the content root, in base units.
    default property alias content: contentRoot.data

    implicitWidth: card.width
    implicitHeight: card.height

    anchors.top: true
    anchors.left: true
    anchors.right: false
    anchors.bottom: false

    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: Tokens.ns.widgets
    exclusionMode: ExclusionMode.Ignore

    mask: Region {
        Region { item: card }
    }

    visible: Config.desktopWidgets && !root.forceHidden

    readonly property real screenW: Quickshell.screens[0].width
    readonly property real screenH: Quickshell.screens[0].height

    readonly property real storedX: widgetId === "fetch" ? Config.fetchX
        : Config.vinylX
    readonly property real storedY: widgetId === "fetch" ? Config.fetchY
        : Config.vinylY

    readonly property real homeX: storedX >= 0 ? storedX
        : defaultRight ? screenW - width - defaultMargin : defaultMargin
    readonly property real homeY: storedY >= 0 ? storedY
        : defaultBottom ? screenH - height - defaultMargin : defaultMargin

    property real dx: 0
    property real dy: 0

    margins.left: root.homeX + root.dx
    margins.top: root.homeY + root.dy

    Surface {
        id: card

        width: root.cardW * root.liveScale
        height: root.cardH * root.liveScale

        level: 2
        radius: 16
        lifted: dragArea.containsMouse || grip.containsMouse

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
                easing.bezierCurve: Motion.standard
            }
        }
    }

    // The content: one block in base units, scaled as a whole. Anchors inside
    // it refer to the base size, never to the card's scaled pixels.
    Item {
        id: contentRoot

        x: 0
        y: 0
        width: root.cardW
        height: root.cardH
        transformOrigin: Item.TopLeft
        scale: root.liveScale
    }

    // The global cursor position, from a local mouse event: the window's own
    // origin plus the event's local coordinates. Computing deltas in GLOBAL
    // terms is what makes the drag track the cursor 1:1 -- using the local x
    // made the window chase its own tail at half speed until the pointer
    // escaped the card.
    function globalAt(area, mouse) {
        return Qt.point(root.homeX + root.dx + area.x + mouse.x,
            root.homeY + root.dy + area.y + mouse.y);
    }

    MouseArea {
        id: dragArea

        // Declared before the content, so content items with handlers still
        // win their own clicks.
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        hoverEnabled: true
        cursorShape: dragArea.pressed ? Qt.SizeAllCursor
            : Qt.PointingHandCursor

        property point pressGlobal: Qt.point(0, 0)
        property point pressOffset: Qt.point(0, 0)

        onPressed: function (mouse) {
            dragArea.pressOffset = Qt.point(root.dx, root.dy);
            dragArea.pressGlobal = root.globalAt(dragArea, mouse);
        }

        onPositionChanged: function (mouse) {
            if (!dragArea.pressed)
                return;
            const g = root.globalAt(dragArea, mouse);
            root.dx = dragArea.pressOffset.x + g.x - dragArea.pressGlobal.x;
            root.dy = dragArea.pressOffset.y + g.y - dragArea.pressGlobal.y;
        }

        onReleased: {
            const moved = Math.abs(root.dx) + Math.abs(root.dy);

            if (moved < 6) {
                root.dx = 0;
                root.dy = 0;
                root.clicked();
                return;
            }

            // Snap the final position to the grid, then make it the new home
            // so the next drag starts from here.
            const nx = Math.round((root.homeX + root.dx) / 8) * 8;
            const ny = Math.round((root.homeY + root.dy) / 8) * 8;

            root.dx = 0;
            root.dy = 0;
            Config.saveWidgetPos(root.widgetId,
                Math.max(0, Math.min(root.screenW - root.width, nx)),
                Math.max(0, Math.min(root.screenH - root.height, ny)));
        }
    }

    // The resize grip: the bottom-right corner, three dots. Dragging it maps
    // the movement to the zoom, clamped, snapped to 0.05 on release.
    MouseArea {
        id: grip

        width: 20
        height: 20
        anchors.right: card.right
        anchors.bottom: card.bottom
        acceptedButtons: Qt.LeftButton
        hoverEnabled: true
        cursorShape: Qt.SizeFDiagCursor

        property real pressZoomD: 0
        property point pressGlobal: Qt.point(0, 0)

        onPressed: function (mouse) {
            grip.pressZoomD = root.zoomD;
            grip.pressGlobal = root.globalAt(grip, mouse);
        }

        onPositionChanged: function (mouse) {
            if (!grip.pressed)
                return;
            const g = root.globalAt(grip, mouse);
            const delta = (g.x - grip.pressGlobal.x)
                + (g.y - grip.pressGlobal.y);
            root.zoomD = grip.pressZoomD + delta / 300;
        }

        onReleased: {
            const snapped = Math.round(root.liveScale / 0.05) * 0.05;
            Config.saveWidgetScale(root.widgetId,
                Math.max(0.7, Math.min(1.6, snapped)));
            root.zoomD = 0;
        }

        Repeater {
            model: 3

            delegate: Rectangle {
                required property int index

                x: 5 + index * 4
                y: 13 - index * 4
                width: 2
                height: 2
                radius: 1
                color: Qt.rgba(Theme.fg1.r, Theme.fg1.g, Theme.fg1.b,
                    grip.containsMouse ? 0.8 : 0.35)
            }
        }
    }
}
