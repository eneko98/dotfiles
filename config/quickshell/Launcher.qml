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
import Quickshell.Io
import QtQuick

Popup {
    id: root

    panelWidth: 520

    property string query: ""
    property int selectedIndex: 0
    property var vmDefs: []

    // Two providers behind one field: applications by default, and `>vm`
    // for the VM definitions in ~/vm. Each result is a small wrapper so the
    // delegate does not need to know which kind it is until launch().
    readonly property var results: {
        const raw = root.query.trim();
        const lower = raw.toLowerCase();

        if (lower === ">vm" || lower.indexOf(">vm ") === 0) {
            const term = lower.replace(/^>vm\s*/, "");
            const matches = root.vmDefs.filter(function (v) {
                return v.name.toLowerCase().indexOf(term) >= 0
                    || v.label.toLowerCase().indexOf(term) >= 0;
            });
            matches.sort(function (a, b) { return a.label.localeCompare(b.label); });
            return matches.map(function (v) {
                return {
                    kind: "vm",
                    vmName: v.name,
                    name: v.label,
                    icon: "",
                    comment: v.memory + " · " + v.cpus + " vCPU",
                    genericName: ""
                };
            });
        }

        const all = DesktopEntries.applications.values;
        const q = lower;
        const byName = function (a, b) { return a.name.localeCompare(b.name); };
        const wrap = function (entry) {
            return {
                kind: "app",
                entry: entry,
                name: entry.name,
                icon: entry.icon,
                comment: entry.comment,
                genericName: entry.genericName
            };
        };

        if (q === "")
            return all.slice().sort(byName).map(wrap);

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
        return starts.concat(contains).map(wrap);
    }

    function open() {
        root.query = "";
        root.selectedIndex = 0;
        vmList.running = false;
        vmList.running = true;
        root.visible = true;
        // The Popup shell focuses its panel when it becomes visible; the input
        // has to win that race.
        Qt.callLater(function () { input.forceActiveFocus(); });
    }

    // Used by `qs ipc call launcher query "..."` and by tests.
    function setQuery(text) {
        root.visible = true;
        root.query = text;
        root.selectedIndex = 0;
        input.text = text;
        if (root.vmDefs.length === 0) {
            vmList.running = false;
            vmList.running = true;
        }
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

    function launch(item) {
        root.close();

        if (item.kind === "vm") {
            Quickshell.execDetached([
                Quickshell.env("HOME") + "/.config/hypr/scripts/vm-run",
                item.vmName
            ]);
            return;
        }

        const entry = item.entry;
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

    // The VM definitions are cheap to read; loading them on open keeps the
    // `>vm` provider in step with ~/vm without a watcher.
    Process {
        id: vmList

        command: ["sh", "-c", "$HOME/.config/hypr/scripts/vm-list"]

        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                const lines = text.split("\n");
                for (const line of lines) {
                    if (line.trim() === "")
                        continue;
                    try {
                        out.push(JSON.parse(line));
                    } catch (e) {}
                }
                root.vmDefs = out;
            }
        }
    }

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
            text: "Search apps · >vm for VMs"
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

            Text {
                id: vmIcon

                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                visible: row.modelData.kind === "vm"
                text: "󰒓"
                color: Theme.gold
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 16
            }

            Image {
                id: appIcon

                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                width: 20
                height: 20
                visible: row.modelData.kind !== "vm" && row.modelData.icon !== ""
                source: visible ? Quickshell.iconPath(row.modelData.icon) : ""
                sourceSize.width: 20
                sourceSize.height: 20
                fillMode: Image.PreserveAspectFit
            }

            Text {
                anchors.left: row.modelData.kind === "vm" ? vmIcon.right
                    : appIcon.visible ? appIcon.right : parent.left
                anchors.leftMargin: row.modelData.kind === "vm" ? 10
                    : appIcon.visible ? 10 : 12
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
                anchors.left: row.modelData.kind === "vm" ? vmIcon.right
                    : appIcon.visible ? appIcon.right : parent.left
                anchors.leftMargin: row.modelData.kind === "vm" ? 10
                    : appIcon.visible ? 10 : 12
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
        text: root.query.trim().toLowerCase().indexOf(">vm") === 0
            ? "No VMs match" : "No applications match"
        color: Theme.fg2
        font.family: "Adwaita Sans"
        font.pixelSize: 11
    }
}
