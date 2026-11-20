// The VM laboratory: the definitions in ~/vm/*.json, the transient units
// vm-*.service and one QMP client per VM. Start, pause and stop from here;
// the running state refreshes only while the panel is open.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

Popup {
    id: root

    panelWidth: 520

    property var runningMap: ({})

    ListModel { id: vmModel }
    ListModel { id: containerModel }

    function refreshDefinitions() {
        vmModel.clear();
        defs.running = false;
        defs.running = true;
    }

    function refreshUnits() {
        units.running = false;
        units.running = true;
    }

    function refreshAll() {
        refreshDefinitions();
        refreshUnits();
        refreshContainers();
    }

    function refreshContainers() {
        containers.running = false;
        containers.running = true;
    }

    function startVm(name) {
        Quickshell.execDetached([
            Quickshell.env("HOME") + "/.config/hypr/scripts/vm-run", name
        ]);
        refreshTimer.restart();
    }

    function stopVm(name) {
        Quickshell.execDetached([
            Quickshell.env("HOME") + "/.config/hypr/scripts/vm-stop", name
        ]);
        refreshTimer.restart();
    }

    function startContainer(id) {
        Quickshell.execDetached(["podman", "start", id]);
        refreshTimer.restart();
    }

    function stopContainer(id) {
        Quickshell.execDetached(["podman", "stop", id]);
        refreshTimer.restart();
    }

    function removeContainer(id) {
        Quickshell.execDetached(["podman", "rm", id]);
        refreshTimer.restart();
    }

    Connections {
        target: root

        function onVisibleChanged() {
            if (root.visible) {
                root.refreshAll();
                refreshLoop.running = true;
            } else {
                refreshLoop.running = false;
            }
        }
    }

    Timer {
        id: refreshLoop
        interval: 2000
        repeat: true
        running: false
        onTriggered: {
            root.refreshUnits();
            root.refreshContainers();
        }
    }

    Timer {
        id: refreshTimer
        interval: 1200
        onTriggered: {
            if (root.visible)
                root.refreshAll();
        }
    }

    Process {
        id: defs

        command: ["sh", "-c", "$HOME/.config/hypr/scripts/vm-list"]

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n");
                for (const line of lines) {
                    if (line.trim() === "")
                        continue;
                    try {
                        vmModel.append(JSON.parse(line));
                    } catch (e) {}
                }
            }
        }
    }

    Process {
        id: units

        command: ["systemctl", "--user", "list-units", "vm-*.service",
            "--state=active", "--plain", "--no-legend"]

        stdout: StdioCollector {
            onStreamFinished: {
                const map = {};
                const lines = text.split("\n");
                for (const line of lines) {
                    const parts = line.trim().split(/\s+/);
                    if (parts.length < 4)
                        continue;
                    const unit = parts[0];
                    if (!unit.startsWith("vm-") || !unit.endsWith(".service"))
                        continue;
                    map[unit.slice(3, -8)] = parts[3];
                }
                root.runningMap = map;
            }
        }
    }

    Process {
        id: containers

        command: ["podman", "ps", "-a", "--format", "json"]

        stdout: StdioCollector {
            onStreamFinished: {
                containerModel.clear();
                let list = [];
                try {
                    list = JSON.parse(text);
                } catch (e) {
                    return;
                }
                if (!Array.isArray(list))
                    return;
                for (const c of list) {
                    containerModel.append({
                        cid: c.Id,
                        name: c.Names && c.Names.length > 0
                            ? c.Names[0] : c.Id.slice(0, 12),
                        image: c.Image,
                        state: c.State,
                        status: c.Status
                    });
                }
            }
        }
    }

    Text {
        text: "Lab"
        color: Theme.fg0
        font.family: "Adwaita Sans"
        font.pixelSize: 15
        font.bold: true
    }

    Text {
        visible: vmModel.count === 0
        text: "No VM definitions in ~/vm"
        color: Theme.fg1
        font.family: "Adwaita Sans"
        font.pixelSize: 12
    }

    Repeater {
        model: vmModel

        delegate: Surface {
            id: row

            required property string name
            required property string label
            required property string memory
            required property int cpus

            width: parent.width
            height: 72
            level: 2
            radius: Tokens.radius.card

            readonly property string systemState: root.runningMap[row.name] || ""
            readonly property bool running: row.systemState !== ""

            // The QEMU window is a normal toplevel; the overview's
            // ScreencopyView captures it without QMP screendump (which fails
            // on virtio-vga-gl) and without grabbing whatever is on top.
            readonly property var preview: {
                const list = Hyprland.toplevels.values;
                for (let i = 0; i < list.length; ++i) {
                    const title = list[i].title || "";
                    if (title.indexOf("QEMU (" + row.name + ")") === 0)
                        return list[i];
                }
                return null;
            }

            VmClient {
                id: client
                name: row.name
                active: row.running
                visible: false
            }

            Item {
                id: thumb

                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                width: 112
                height: 63
                clip: true

                Rectangle {
                    anchors.fill: parent
                    radius: 6
                    color: Theme.bg0
                    border.width: 1
                    border.color: Qt.rgba(Theme.fg0.r, Theme.fg0.g, Theme.fg0.b, 0.08)
                }

                ScreencopyView {
                    anchors.fill: parent
                    visible: row.running && row.preview !== null
                    captureSource: visible ? row.preview.wayland : null
                    live: false
                    constraintSize: Qt.size(224, 126)
                }

                Text {
                    anchors.centerIn: parent
                    visible: !row.running || row.preview === null
                    text: "󰒓"
                    color: Theme.fg2
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 22
                }
            }

            Column {
                width: row.width - 250
                anchors.left: thumb.right
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    width: parent.width
                    text: row.label
                    color: Theme.fg0
                    font.family: "Adwaita Sans"
                    font.pixelSize: 13
                    font.bold: true
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: row.memory + " · " + row.cpus + " vCPU · "
                        + (row.running
                            ? (client.ready ? client.status : row.systemState)
                            : "stopped")
                    color: Theme.fg1
                    font.family: "Adwaita Sans"
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Pressable {
                    visible: !row.running
                    width: 48
                    height: 26
                    onClicked: root.startVm(row.name)

                    Rectangle {
                        anchors.fill: parent
                        radius: Tokens.radius.control
                        color: parent.hovered
                            ? Qt.rgba(Theme.bg2.r, Theme.bg2.g, Theme.bg2.b, 0.95)
                            : Qt.rgba(Theme.bg2.r, Theme.bg2.g, Theme.bg2.b, 0.70)
                        border.width: 1
                        border.color: Qt.rgba(Theme.fg0.r, Theme.fg0.g, Theme.fg0.b, 0.10)
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "Start"
                        color: Theme.fg1
                        font.family: "Adwaita Sans"
                        font.pixelSize: 11
                    }
                }

                Pressable {
                    visible: row.running
                    width: 52
                    height: 26
                    onClicked: {
                        if (!client.ready)
                            return;
                        if (client.status === "paused")
                            client.resume();
                        else
                            client.pause();
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: Tokens.radius.control
                        color: parent.hovered
                            ? Qt.rgba(Theme.bg2.r, Theme.bg2.g, Theme.bg2.b, 0.95)
                            : Qt.rgba(Theme.bg2.r, Theme.bg2.g, Theme.bg2.b, 0.70)
                        border.width: 1
                        border.color: Qt.rgba(Theme.fg0.r, Theme.fg0.g, Theme.fg0.b, 0.10)
                    }

                    Text {
                        anchors.centerIn: parent
                        text: client.status === "paused" ? "Resume" : "Pause"
                        color: Theme.fg1
                        font.family: "Adwaita Sans"
                        font.pixelSize: 11
                    }
                }

                Pressable {
                    visible: row.running
                    width: 44
                    height: 26
                    onClicked: root.stopVm(row.name)

                    Rectangle {
                        anchors.fill: parent
                        radius: Tokens.radius.control
                        color: parent.hovered
                            ? Qt.rgba(Theme.bg2.r, Theme.bg2.g, Theme.bg2.b, 0.95)
                            : Qt.rgba(Theme.bg2.r, Theme.bg2.g, Theme.bg2.b, 0.70)
                        border.width: 1
                        border.color: Qt.rgba(Theme.fg0.r, Theme.fg0.g, Theme.fg0.b, 0.10)
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "Stop"
                        color: Theme.fg1
                        font.family: "Adwaita Sans"
                        font.pixelSize: 11
                    }
                }
            }
        }
    }

    // --- Containers -------------------------------------------------------
    Rectangle {
        width: parent.width
        height: 1
        color: Qt.rgba(Theme.fg0.r, Theme.fg0.g, Theme.fg0.b, 0.06)
    }

    Text {
        text: "Containers"
        color: Theme.fg1
        font.family: "Adwaita Sans"
        font.pixelSize: 12
        font.bold: true
    }

    Text {
        visible: containerModel.count === 0
        text: "No containers"
        color: Theme.fg2
        font.family: "Adwaita Sans"
        font.pixelSize: 11
    }

    Repeater {
        model: containerModel

        delegate: Surface {
            id: cRow

            required property string cid
            required property string name
            required property string image
            required property string state
            required property string status

            width: parent.width
            height: 64
            level: 2
            radius: Tokens.radius.card

            readonly property bool running: cRow.state === "running"

            Column {
                width: cRow.width - 200
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    width: parent.width
                    text: cRow.name
                    color: Theme.fg0
                    font.family: "Adwaita Sans"
                    font.pixelSize: 13
                    font.bold: true
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: cRow.image + " · " + cRow.status
                    color: Theme.fg1
                    font.family: "Adwaita Sans"
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Pressable {
                    visible: !cRow.running
                    width: 48
                    height: 26
                    onClicked: root.startContainer(cRow.cid)

                    Rectangle {
                        anchors.fill: parent
                        radius: Tokens.radius.control
                        color: parent.hovered
                            ? Qt.rgba(Theme.bg2.r, Theme.bg2.g, Theme.bg2.b, 0.95)
                            : Qt.rgba(Theme.bg2.r, Theme.bg2.g, Theme.bg2.b, 0.70)
                        border.width: 1
                        border.color: Qt.rgba(Theme.fg0.r, Theme.fg0.g, Theme.fg0.b, 0.10)
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "Start"
                        color: Theme.fg1
                        font.family: "Adwaita Sans"
                        font.pixelSize: 11
                    }
                }

                Pressable {
                    visible: cRow.running
                    width: 44
                    height: 26
                    onClicked: root.stopContainer(cRow.cid)

                    Rectangle {
                        anchors.fill: parent
                        radius: Tokens.radius.control
                        color: parent.hovered
                            ? Qt.rgba(Theme.bg2.r, Theme.bg2.g, Theme.bg2.b, 0.95)
                            : Qt.rgba(Theme.bg2.r, Theme.bg2.g, Theme.bg2.b, 0.70)
                        border.width: 1
                        border.color: Qt.rgba(Theme.fg0.r, Theme.fg0.g, Theme.fg0.b, 0.10)
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "Stop"
                        color: Theme.fg1
                        font.family: "Adwaita Sans"
                        font.pixelSize: 11
                    }
                }

                Pressable {
                    visible: !cRow.running
                    width: 56
                    height: 26
                    onClicked: root.removeContainer(cRow.cid)

                    Rectangle {
                        anchors.fill: parent
                        radius: Tokens.radius.control
                        color: parent.hovered
                            ? Qt.rgba(Theme.bg2.r, Theme.bg2.g, Theme.bg2.b, 0.95)
                            : Qt.rgba(Theme.bg2.r, Theme.bg2.g, Theme.bg2.b, 0.70)
                        border.width: 1
                        border.color: Qt.rgba(Theme.fg0.r, Theme.fg0.g, Theme.fg0.b, 0.10)
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "Remove"
                        color: Theme.fg1
                        font.family: "Adwaita Sans"
                        font.pixelSize: 11
                    }
                }
            }
        }
    }
}
