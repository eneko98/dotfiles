// A desktop widget: a card floating over the wallpaper, architecture B.
//
// THE WINDOW IS NOT THE CARD. It is the card plus room for its shadow on
// every side (`pad`), cut to the screen. Everywhere except at an edge the
// window moves and the card sits still inside it; at an edge the window is
// clipped and the card moves in QML, which is synchronous. There is never
// double movement, and the shadow is never cut by the window edge (the bug
// the old implicitWidth: card.width had).
//
// THE DRAG READS THE CURSOR FROM HYPRLAND, not from the mouse event. The
// event's local x is relative to a window this very drag is moving: the old
// implementation fed that back into itself and vibrated (measured). j/cursorpos
// answers in layout coordinates -- the frame the card actually lives in --
// and Hyprland closes the connection after every reply, so each poll is a
// fresh connection, only while a gesture is on.
//
// SCALING. cardW/cardH are base units; the content is authored in them and
// scaled as one block (the scene graph rasterizes text at the final size, so
// zooming does not blur it). `scaleShown` is the ONLY animated size value:
// card, content and window all read it, so they can never disagree (the old
// code animated the card with a Behavior while the content jumped at once).
//
// No clicks: press-and-move drags, the corner grip resizes, a release
// without movement does nothing.
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: root

    // --- public contract ---
    property string widgetId: ""
    property bool defaultRight: true
    property bool defaultBottom: true
    property real defaultMargin: 24
    property bool forceHidden: false

    // Per-widget switch from the control centre. Position and scale survive:
    // turning a widget back on puts it exactly where it was.
    readonly property bool enabled: widgetId === "fetch"
        ? Config.fetchEnabled : Config.vinylEnabled
    property real cardW: 0
    property real cardH: 0
    default property alias content: contentRoot.data

    // For the content: the live zoom (Image.sourceSize) and the gesture state.
    readonly property real currentScale: root.scaleShown
    readonly property bool interacting: root.dragging || root.resizing

    // True when the focused workspace has no windows over the desktop: an
    // ambient card that nobody can see should not spin or poll. The vinyl
    // reads this; the fetch needs nothing from it.
    readonly property bool desktopSeen: {
        const list = Hyprland.workspaces.values;
        for (let i = 0; i < list.length; ++i) {
            if (list[i].focused)
                return list[i].toplevels.values.length === 0;
        }
        return true;
    }

    // --- the window ---
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: Tokens.ns.widgets
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    screen: Quickshell.screens[0]
    visible: Config.desktopWidgets && root.enabled && !root.forceHidden

    readonly property real screenW: Quickshell.screens[0].width
    readonly property real screenH: Quickshell.screens[0].height

    // Room for the shadow: level 2 is blur 16 + y offset 3 (Tokens), so 24
    // covers it with margin on every side. The blur behind the card comes
    // from the layer rule's ignore_alpha, not from a bigger fill.
    readonly property int pad: 24

    // --- position ---
    readonly property real storedX: widgetId === "fetch"
        ? Config.fetchX : Config.vinylX
    readonly property real storedY: widgetId === "fetch"
        ? Config.fetchY : Config.vinylY

    // NaN at rest; the home binding stays alive underneath.
    property real liveX: NaN
    property real liveY: NaN

    readonly property real homeX: storedX >= 0 ? storedX
        : defaultRight ? screenW - cardWpx - defaultMargin : defaultMargin
    readonly property real homeY: storedY >= 0 ? storedY
        : defaultBottom ? screenH - cardHpx - defaultMargin
        : Tokens.topInset + defaultMargin

    readonly property real cardX: Math.round(isNaN(root.liveX)
        ? root.homeX : root.liveX)
    readonly property real cardY: Math.round(isNaN(root.liveY)
        ? root.homeY : root.liveY)

    readonly property real edge: 8

    function clampX(x) {
        return Math.max(root.edge,
            Math.min(root.screenW - root.edge - root.cardWpx, x));
    }

    function clampY(y) {
        return Math.max(Tokens.topInset + root.edge,
            Math.min(root.screenH - root.edge - root.cardHpx, y));
    }

    // --- size ---
    readonly property real minScale: 0.8
    readonly property real maxScale: 1.6

    readonly property real storedScale: widgetId === "fetch"
        ? Config.fetchScale : Config.vinylScale

    property real liveScale: NaN

    readonly property real targetScale: Math.max(root.minScale,
        Math.min(root.maxScale,
            isNaN(root.liveScale) ? root.storedScale : root.liveScale))

    // The one animated size value.
    property real scaleShown: root.targetScale

    Behavior on scaleShown {
        enabled: !root.resizing
        NumberAnimation {
            duration: Motion.fast
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.standard
        }
    }

    readonly property real cardWpx: Math.round(root.cardW * root.scaleShown)
    readonly property real cardHpx: Math.round(root.cardH * root.scaleShown)

    // While the grip is held the window is sized for the largest scale that
    // fits, so growing never clips and the layer does not reconfigure per frame.
    property real resizeMaxFit: root.maxScale
    readonly property real boxW: root.resizing
        ? Math.ceil(root.cardW * root.resizeMaxFit) : root.cardWpx
    readonly property real boxH: root.resizing
        ? Math.ceil(root.cardH * root.resizeMaxFit) : root.cardHpx

    readonly property int winL: Math.max(0, Math.round(root.cardX) - root.pad)
    readonly property int winT: Math.max(0, Math.round(root.cardY) - root.pad)
    readonly property int winR: Math.min(root.screenW,
        Math.round(root.cardX + root.boxW + root.pad))
    readonly property int winB: Math.min(root.screenH,
        Math.round(root.cardY + root.boxH + root.pad))

    anchors.top: true
    anchors.left: true
    margins.left: root.winL
    margins.top: root.winT
    implicitWidth: root.winR - root.winL
    implicitHeight: root.winB - root.winT

    mask: Region {
        Region { item: card }
    }

    // --- the card ---
    Surface {
        id: card

        x: root.cardX - root.winL
        y: root.cardY - root.winT
        width: root.cardWpx
        height: root.cardHpx

        // The corner follows the zoom; a fixed 16 at 1.6x would read square.
        radius: Math.max(8, Math.round(16 * root.scaleShown))

        level: 2
        // No `extra`: the level's default fill is fillSolid 0.94, which is
        // the opacity the design measured for fg1 on a light wallpaper
        // (4.77:1). More opacity loses the wallpaper tint for nothing.
        lifted: hover.hovered || grip.containsMouse || root.interacting
    }

    // --- the drag zone ---
    // Below the content in z, so content items with their own handlers keep
    // their events. A DragHandler rather than a MouseArea: it does not take
    // the press exclusively, so the grip above it still sees it.
    Item {
        id: hit

        x: card.x
        y: card.y
        width: card.width
        height: card.height

        HoverHandler {
            id: hover
            // Open hand: the card can be grabbed; it does not promise a click.
            cursorShape: Qt.OpenHandCursor
        }

        DragHandler {
            id: dragger

            target: null
            dragThreshold: 4
            cursorShape: Qt.ClosedHandCursor

            onActiveChanged: active
                ? root.beginDrag(centroid.pressPosition)
                : root.endDrag()
            onCanceled: root.endDrag()
        }
    }

    // --- the content ---
    // One block in base units, scaled as a whole. Anchors inside it refer to
    // the base size, never to the card's scaled pixels.
    Item {
        id: contentRoot

        x: card.x
        y: card.y
        width: root.cardW
        height: root.cardH
        transformOrigin: Item.TopLeft
        scale: root.scaleShown
    }

    // --- drag state ---
    property bool dragging: false
    property real grabX: 0
    property real grabY: 0

    function beginDrag(p) {
        root.grabX = p.x;
        root.grabY = p.y;
        root.liveX = root.cardX;
        root.liveY = root.cardY;
        root.dragging = true;
    }

    function endDrag() {
        if (!root.dragging)
            return;
        root.dragging = false;
        const nx = root.clampX(Math.round(root.liveX / 8) * 8);
        const ny = root.clampY(Math.round(root.liveY / 8) * 8);
        // Save first, then drop the override: the other order snaps the card
        // back to the old home for one frame.
        Config.saveWidgetPos(root.widgetId, nx, ny);
        root.liveX = NaN;
        root.liveY = NaN;
    }

    // The absolute cursor, from Hyprland's request socket. `connected` is the
    // on/off switch; the reply arrives through the parser before Hyprland
    // hangs up and `connectionStateChanged` drops it again.
    readonly property string hyprSocket: {
        const sig = Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE");
        const run = Quickshell.env("XDG_RUNTIME_DIR");
        return sig && run ? run + "/hypr/" + sig + "/.socket.sock" : "";
    }

    Socket {
        id: cursorSocket

        path: root.hyprSocket

        property string reply: ""

        onConnectionStateChanged: {
            if (connected) {
                cursorSocket.reply = "";
                cursorSocket.write("j/cursorpos");
                cursorSocket.flush();
            }
        }

        parser: SplitParser {
            splitMarker: ""

            onRead: function (data) {
                cursorSocket.reply += data;
                const m = cursorSocket.reply.match(
                    /"x":\s*(-?\d+)[\s\S]*"y":\s*(-?\d+)/);
                if (m === null)
                    return;
                cursorSocket.connected = false;
                root.followCursor(Number(m[1]), Number(m[2]));
            }
        }
    }

    // One poll per frame while dragging. Quickshell 0.3.2 has no
    // FrameAnimation (checked in its qmltypes); a 16 ms Timer is the same
    // thing here, and it only runs during a gesture.
    Timer {
        interval: 16
        running: root.dragging && root.hyprSocket !== ""
        repeat: true

        onTriggered: {
            if (!cursorSocket.connected)
                cursorSocket.connected = true;
        }
    }

    function followCursor(gx, gy) {
        if (!root.dragging)
            return;   // a reply that landed after release
        root.liveX = root.clampX(gx - root.screen.x - root.grabX);
        root.liveY = root.clampY(gy - root.screen.y - root.grabY);
    }

    // --- resize state ---
    property bool resizing: false

    function beginResize() {
        // A widget still on its default corner computes that corner from its
        // size: freeze the position first, or the card grows away from the
        // cursor towards the top-left.
        if (root.storedX < 0 || root.storedY < 0)
            Config.saveWidgetPos(root.widgetId, root.cardX, root.cardY);

        // Once, not as a binding: as a binding it loops with homeX on the
        // widgets that have no stored position yet.
        root.resizeMaxFit = Math.min(root.maxScale,
            (root.screenW - root.edge - root.cardX) / root.cardW,
            (root.screenH - root.edge - root.cardY) / root.cardH);
        root.resizing = true;               // the Behavior turns off first...
        root.liveScale = root.scaleShown;   // ...then the gesture owns it
    }

    function endResize() {
        if (!root.resizing)
            return;
        const s = Math.max(root.minScale, Math.min(root.resizeMaxFit,
            Math.round(root.liveScale / 0.05) * 0.05));
        root.resizing = false;              // Behavior back on, then the snap
        Config.saveWidgetScale(root.widgetId, s);
        root.liveScale = NaN;               // animates the <=0.025 remainder
    }

    // The scale that puts the card's bottom-right corner nearest the cursor
    // is the projection of the corner offset onto the card's diagonal.
    // EVERYTHING HERE IS IN WINDOW COORDINATES: the corner arrives from the
    // grip's own MouseArea, and during a resize the window does not move, so
    // window and screen differ by a constant (winL/winT). Subtracting the
    // SCREEN-side cardX instead of the window-side card.x made every
    // projection negative and clamped the gesture to minScale: the instant
    // shrink that could not grow back (measured on the user's hand).
    function resizeTo(cornerX, cornerY) {
        const a = cornerX - card.x;
        const b = cornerY - card.y;
        const s = (root.cardW * a + root.cardH * b)
            / (root.cardW * root.cardW + root.cardH * root.cardH);
        root.liveScale = Math.max(root.minScale, Math.min(root.resizeMaxFit, s));
    }

    // Test hook: no pointer can be injected on this machine, so the resize
    // gesture is driven from the `widgets` IPC. dx/dy are px from the card's
    // current corner, the same thing a hand dragging the grip produces.
    function testResize(dx, dy) {
        root.beginResize();
        root.resizeTo(card.x + card.width + dx, card.y + card.height + dy);
        root.endResize();
    }

    // --- the grip ---
    // The card's corner. A MouseArea, because it takes the press exclusively
    // and the DragHandler never sees it; drawn as an arc concentric with the
    // corner, so it reads as part of the card instead of as a widget bolted
    // onto it. Invisible at rest: a clean card.
    MouseArea {
        id: grip

        width: 24
        height: 24
        x: card.x + card.width - width
        y: card.y + card.height - height
        hoverEnabled: true
        preventStealing: true
        cursorShape: Qt.SizeFDiagCursor

        // Pointer-to-corner offset at press, so the corner does not jump.
        property real offX: 0
        property real offY: 0

        onPressed: function (mouse) {
            root.beginResize();
            grip.offX = card.x + card.width - (grip.x + mouse.x);
            grip.offY = card.y + card.height - (grip.y + mouse.y);
        }

        onPositionChanged: function (mouse) {
            if (!grip.pressed)
                return;
            // Exact even though the grip itself moves with the corner: Qt
            // computes the event's local coordinates from the item's current
            // position, and during a resize the window does not move.
            root.resizeTo(grip.x + mouse.x + grip.offX,
                grip.y + mouse.y + grip.offY);
        }

        onReleased: root.endResize()
        onCanceled: root.endResize()

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            opacity: grip.pressed ? 1
                : grip.containsMouse ? 0.9
                : hover.hovered ? 0.5 : 0

            Behavior on opacity {
                NumberAnimation { duration: Motion.fast }
            }

            ShapePath {
                strokeColor: Theme.fg1
                strokeWidth: 2
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap

                // PathAngleArc: 0 deg at 3 o'clock, positive clockwise, so
                // 15..75 sweeps the bottom-right corner.
                PathAngleArc {
                    centerX: grip.width - card.radius
                    centerY: grip.height - card.radius
                    radiusX: card.radius - 4
                    radiusY: card.radius - 4
                    startAngle: 15
                    sweepAngle: 60
                }
            }
        }
    }
}
