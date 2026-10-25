// The application launcher: a search field over DesktopEntries, with keyboard
// selection and a click to launch. It replaces fuzzel for SUPER + Space only;
// fuzzel stays the dmenu for the clipboard and session scripts.
//
// DesktopEntries.applications already excludes Hidden and NoDisplay entries, so
// the list is what a menu should show. Filtering is a simple startsWith-first
// then contains search over name, generic name, comment and keywords — a real
// fuzzy scorer would be the next step, not a pretending one.
//
// Terminal entries need kitty -e by hand: DesktopEntry.execute() deliberately
// ignores runInTerminal.

import Quickshell
import QtQuick

Popup {
    id: root

    panelWidth: 520
    centerVertically: true

    property string query: ""
    property int selectedIndex: 0

    readonly property var results: {
        const all = DesktopEntries.applications.values;
        const q = root.query.trim().toLowerCase();
        const byName = function (a, b) { return a.name.localeCompare(b.name); };

        if (q === "")
            return all.slice().sort(byName);

        const starts = [];
        const contains = [];

        for (let i = 0; i < all.length; ++i) {
            const entry = all[i];
            const name = entry.name.toLowerCase();
            const haystack = (entry.name + " " + entry.genericName + " " + entry.comment
                + " " + entry.keywords.join(" ")).toLowerCase();

            if (name.indexOf(q) === 0)
                starts.push(entry);
            else if (haystack.indexOf(q) >= 0)
                contains.push(entry);
        }

        starts.sort(byName);
        contains.sort(byName);
        return starts.concat(contains);
    }

    function open() {
        root.query = "";
        root.selectedIndex = 0;
        root.visible = true;
        // The Popup shell focuses its panel when it becomes visible; the input
        // has to win that race.
        Qt.callLater(function () { input.forceActiveFocus(); });
    }

    function close() {
        root.visible = false;
        root.query = "";
    }

    function move(step) {
        if (root.results.length === 0)
            return;

        root.selectedIndex = (root.selectedIndex + step + root.results.length)
            % root.results.length;
    }

    function launch(entry) {
        root.close();

        if (entry.runInTerminal) {
            Quickshell.execDetached({
                command: ["kitty", "-e"].concat(entry.command),
                workingDirectory: entry.workingDirectory
            });
        } else {
            entry.execute();
        }
    }

    function launchSelected() {
        if (root.results.length > 0)
            root.launch(root.results[root.selectedIndex]);
    }

    onResultsChanged: if (root.selectedIndex >= root.results.length)
        root.selectedIndex = 0

    // Keep the selected row in view without binding ListView.currentIndex (the
    // view writes that property itself on model changes).
    Connections {
        target: root

        function onSelectedIndexChanged() {
            Qt.callLater(function () {
                list.positionViewAtIndex(root.selectedIndex, ListView.Contain);
            });
        }
    }

    // --- Search field -----------------------------------------------------
    Rectangle {
        width: parent.width
        height: 46
        radius: 8
        color: Theme.bg0
        border.width: 1
        border.color: input.activeFocus ? Theme.gold : Theme.bg2

        Text {
            id: searchGlyph

            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: "󰍉"
            color: Theme.fg2
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 16
        }

        Text {
            anchors.left: searchGlyph.right
            anchors.leftMargin: 10
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            visible: input.text.length === 0
            text: "Search applications"
            color: Theme.fg2
            font.family: "Adwaita Sans"
            font.pixelSize: 13
        }

        TextInput {
            id: input

            anchors.left: searchGlyph.right
            anchors.leftMargin: 10
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            verticalAlignment: TextInput.AlignVCenter
            color: Theme.fg0
            selectionColor: Theme.gold
            selectedTextColor: Theme.bg0
            font.family: "Adwaita Sans"
            font.pixelSize: 13
            focus: true

            onTextChanged: {
                root.query = text;
                root.selectedIndex = 0;
            }

            onAccepted: root.launchSelected()

            Keys.onDownPressed: root.move(1)
            Keys.onUpPressed: root.move(-1)
            Keys.onEscapePressed: root.close()
        }
    }

    // --- Results ----------------------------------------------------------
    ListView {
        id: list

        width: parent.width
        height: Math.min(contentHeight, 360)
        model: root.results
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        delegate: Rectangle {
            id: row

            required property int index
            required property var modelData

            width: list.width
            height: 36
            radius: 6
            color: row.index === root.selectedIndex ? Theme.bg2
                : rowHover.containsMouse ? Qt.rgba(Theme.bg2.r, Theme.bg2.g, Theme.bg2.b, 0.5)
                : "transparent"

            Rectangle {
                visible: row.index === root.selectedIndex
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 2
                height: 20
                radius: 1
                color: Theme.gold
            }

            Image {
                id: appIcon

                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                width: 20
                height: 20
                visible: row.modelData.icon !== ""
                source: row.modelData.icon !== "" ? Quickshell.iconPath(row.modelData.icon) : ""
                sourceSize.width: 20
                sourceSize.height: 20
                fillMode: Image.PreserveAspectFit
            }

            Text {
                anchors.left: appIcon.visible ? appIcon.right : parent.left
                anchors.leftMargin: appIcon.visible ? 10 : 12
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.top: parent.top
                anchors.topMargin: 6
                text: row.modelData.name
                color: Theme.fg0
                font.family: "Adwaita Sans"
                font.pixelSize: 12
                elide: Text.ElideRight
            }

            Text {
                anchors.left: appIcon.visible ? appIcon.right : parent.left
                anchors.leftMargin: appIcon.visible ? 10 : 12
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.top: parent.top
                anchors.topMargin: 20
                visible: text !== ""
                text: row.modelData.comment || row.modelData.genericName
                color: Theme.fg2
                font.family: "Adwaita Sans"
                font.pixelSize: 9
                elide: Text.ElideRight
            }

            MouseArea {
                id: rowHover

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.launch(row.modelData)
            }
        }
    }

    Text {
        visible: root.results.length === 0
        text: "No applications match"
        color: Theme.fg2
        font.family: "Adwaita Sans"
        font.pixelSize: 11
    }
}
