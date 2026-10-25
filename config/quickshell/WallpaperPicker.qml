// The wallpaper picker: a grid of thumbnails from the two places wallpapers
// live, with keyboard selection. Applying one goes through
// config/hypr/scripts/wallpaper, which tells hyprpaper, remembers the path in
// XDG_STATE_HOME and regenerates the lock screen's blurred background.
//
// The list is two directories:
//   - images/wallpapers/ in the repo: committed, license-clean defaults
//   - ~/Pictures/Wallpapers: your own images, untracked
// The derived *-lock.png files are skipped; they are generated, not choices.
//
// A plain `find` through a Process keeps this to one command instead of two
// folder models that would have to be merged in QML.

import Quickshell
import Quickshell.Io
import QtQuick

Popup {
    id: root

    panelWidth: 660
    centerVertically: true

    property var wallpapers: []
    property int selectedIndex: 0

    readonly property int columns: 3

    function open() {
        root.selectedIndex = 0;
        root.visible = true;

        // Re-scan every time: a wallpaper added to ~/Pictures/Wallpapers shows
        // up without restarting the bar.
        listProcess.running = false;
        listProcess.running = true;

        // The Popup shell focuses its panel when it becomes visible; the key
        // catcher has to win that race.
        Qt.callLater(function () { keyCatcher.forceActiveFocus(); });
    }

    function close() {
        root.visible = false;
    }

    function move(step) {
        if (root.wallpapers.length === 0)
            return;

        root.selectedIndex = (root.selectedIndex + step + root.wallpapers.length)
            % root.wallpapers.length;
        Qt.callLater(root.ensureVisible);
    }

    function ensureVisible() {
        if (root.wallpapers.length === 0 || scroller.height <= 0)
            return;

        const cardWidth = (scroller.width - (root.columns - 1) * grid.spacing) / root.columns;
        const rowHeight = cardWidth * 9 / 16 + 16 + grid.spacing;
        const row = Math.floor(root.selectedIndex / root.columns);
        const top = row * rowHeight;

        if (top < scroller.contentY)
            scroller.contentY = top;
        else if (top + rowHeight > scroller.contentY + scroller.height)
            scroller.contentY = top + rowHeight - scroller.height;
    }

    function apply(path) {
        root.close();
        Quickshell.execDetached([
            Quickshell.env("HOME") + "/.config/hypr/scripts/wallpaper", "set", path
        ]);
    }

    function applySelected() {
        if (root.wallpapers.length > 0)
            root.apply(root.wallpapers[root.selectedIndex]);
    }

    // Start on whatever is on the desktop, not on the alphabetically first
    // image, so Enter without moving does not change anything.
    function selectCurrent() {
        if (root.wallpapers.length === 0)
            return;

        const current = stateFile.text().trim();
        const index = root.wallpapers.indexOf(current);

        root.selectedIndex = index >= 0 ? index : 0;
        Qt.callLater(root.ensureVisible);
    }

    FileView {
        id: stateFile

        path: Quickshell.env("HOME") + "/.local/state/dotfiles/wallpaper"
        printErrors: false
    }

    Process {
        id: listProcess

        command: ["sh", "-c",
            "for d in \"$HOME/repos/dotfiles/images/wallpapers\" \"$HOME/Pictures/Wallpapers\"; do "
            + "[ -d \"$d\" ] || continue; "
            + "find \"$d\" -maxdepth 1 -type f "
            + "\\( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \\) "
            + "! -iname '*-lock.png' -print; done | sort"]

        stdout: StdioCollector {
            id: listOut

            onStreamFinished: {
                const lines = listOut.text.split("\n").filter(function (line) {
                    return line !== "";
                });
                root.wallpapers = lines;
                root.selectedIndex = 0;
                root.selectCurrent();
            }
        }
    }

    // --- Header, and the keyboard focus -------------------------------------
    // The panel is focused by Popup.qml; the key catcher takes over from
    // open(), and Escape is left unhandled so it reaches the panel and closes.
    Rectangle {
        id: keyCatcher

        width: parent.width
        height: 20
        color: "transparent"
        focus: true

        Keys.onLeftPressed: root.move(-1)
        Keys.onRightPressed: root.move(1)
        Keys.onUpPressed: root.move(-root.columns)
        Keys.onDownPressed: root.move(root.columns)
        Keys.onReturnPressed: root.applySelected()
        Keys.onEnterPressed: root.applySelected()

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "Wallpaper"
            color: Theme.fg1
            font.family: "Adwaita Sans"
            font.pixelSize: 13
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "Enter to apply · colours follow · Esc to close"
            color: Theme.fg2
            font.family: "Adwaita Sans"
            font.pixelSize: 10
        }
    }

    // --- Thumbnails ---------------------------------------------------------
    Flickable {
        id: scroller

        width: parent.width
        height: Math.min(grid.implicitHeight, 520)
        contentWidth: width
        contentHeight: grid.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Grid {
            id: grid

            width: scroller.width
            columns: root.columns
            spacing: 10

            Repeater {
                model: root.wallpapers

                delegate: Item {
                    id: card

                    required property int index
                    required property var modelData

                    readonly property string path: String(card.modelData)

                    width: (grid.width - (root.columns - 1) * grid.spacing) / root.columns
                    height: width * 9 / 16 + 16

                    Rectangle {
                        id: frame

                        width: parent.width
                        height: parent.height - 16
                        radius: 8
                        color: Theme.bg2
                        clip: true
                        border.width: card.index === root.selectedIndex ? 2 : 1
                        border.color: card.index === root.selectedIndex ? Theme.gold
                            : cardHover.containsMouse
                                ? Qt.rgba(Theme.gold.r, Theme.gold.g, Theme.gold.b, 0.4)
                                : Theme.bg2

                        Image {
                            anchors.fill: parent
                            anchors.margins: card.index === root.selectedIndex ? 2 : 1
                            source: Qt.resolvedUrl(card.path)
                            sourceSize.width: 420
                            sourceSize.height: 236
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                        }
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: frame.bottom
                        anchors.topMargin: 2
                        text: card.path.split("/").pop()
                        color: card.index === root.selectedIndex ? Theme.fg0 : Theme.fg2
                        font.family: "Adwaita Sans"
                        font.pixelSize: 9
                        elide: Text.ElideRight
                    }

                    MouseArea {
                        id: cardHover

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.apply(card.path)
                    }
                }
            }
        }
    }

    Text {
        visible: root.wallpapers.length === 0
        text: "No wallpapers found. Drop images in ~/Pictures/Wallpapers or add CC0 ones under images/wallpapers/."
        color: Theme.fg2
        font.family: "Adwaita Sans"
        font.pixelSize: 10
        wrapMode: Text.Wrap
        width: parent.width
    }
}
