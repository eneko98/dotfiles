// The VM laboratory: the definitions in ~/vm/*.json, the transient units
// vm-*.service and one QMP client per VM. Start, pause and stop from here;
// the running state refreshes only while the panel is open.
import QtQuick
import Quickshell
import Quickshell.Io

Popup {
    id: root

    panelWidth: 400

    property var runningMap: ({})

    ListModel { id: vmModel }

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
    }

    function startVm(name) {
        Quickshell.execDetached([
            Quickshell.env("HOME") + "/.config/hypr/scripts/vm-run", name
        ]);
        refreshTimer.restart();
    }

    function stopVm(name) {
        Quickshell.execDetached(["systemctl", "--user", "stop", "vm-" + name]);
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
        onTriggered: root.refreshUnits()
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
            height: 64
            level: 2

            readonly property string systemState: root.runningMap[row.name] || ""
            readonly property bool running: row.systemState !== ""

            VmClient {
                id: client
                name: row.name
                active: row.running
                visible: false
            }

            Column {
                width: row.width - 170
                anchors.left: parent.left
                anchors.leftMargin: 12
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
}
