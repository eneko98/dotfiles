// A desktop widget: a card floating over the wallpaper.
//
// The window is a Background layer surface, so tiled windows go above it and
// the wallpaper is all that shows around it. Only the card takes input: the
// mask is its own region, the same trick as the bar's, so the rest of the
// surface is transparent for clicks too.
//
// Position: each widget id has an x/y pair in bar-state.json; -1 means "never
// dragged", and the default corner (computed from the screen) is used until
// the user moves it. Press-and-move drags the card -- free while dragging,
// snapped to an 8 px grid on release. A release without movement is a click,
// so the drag area doubles as the card's button and the content never has to
// fight for the pointer.
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

    signal clicked()

    // The card's size, set by the content: it drives the window's size.
    property real cardW: 0
    property real cardH: 0

    // The caller's children land inside the card.
    default property alias content: card.data

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

    // -1 = never placed. Two widgets, two pairs; a generic map would need a
    // JsonAdapter for nested objects, which the flat file does not have.
    readonly property real storedX: widgetId === "fetch" ? Config.fetchX
        : Config.vinylX
    readonly property real storedY: widgetId === "fetch" ? Config.fetchY
        : Config.vinylY

    readonly property real homeX: storedX >= 0 ? storedX
        : defaultRight ? screenW - width - defaultMargin : defaultMargin
    readonly property real homeY: storedY >= 0 ? storedY
        : defaultBottom ? screenH - height - defaultMargin : defaultMargin

    // The live position is home plus a drag offset: writing into the offset
    // keeps the bindings alive, which an imperative write to home would not
    // (the lesson of the `running:` binding on bt-agent).
    property real dx: 0
    property real dy: 0

    margins.left: root.homeX + root.dx
    margins.top: root.homeY + root.dy

    Surface {
        id: card

        level: 2
        radius: 16
        lifted: dragArea.containsMouse
    }

    MouseArea {
        id: dragArea

        // Declared in this file, before the caller's content, so content
        // items still win their own clicks when they have handlers.
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        hoverEnabled: true
        cursorShape: dragArea.pressed ? Qt.SizeAllCursor
            : Qt.PointingHandCursor

        property point pressAt: Qt.point(0, 0)
        property point pressOffset: Qt.point(0, 0)

        onPressed: function (mouse) {
            dragArea.pressAt = Qt.point(mouse.x, mouse.y);
            dragArea.pressOffset = Qt.point(root.dx, root.dy);
        }

        onPositionChanged: function (mouse) {
            if (!dragArea.pressed)
                return;
            root.dx = dragArea.pressOffset.x + mouse.x - dragArea.pressAt.x;
            root.dy = dragArea.pressOffset.y + mouse.y - dragArea.pressAt.y;
        }

        onReleased: function (mouse) {
            const moved = Math.abs(root.dx) + Math.abs(root.dy);

            if (moved < 6) {
                // No movement: a click, and the card goes back home.
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
}
