// One QMP connection to a running VM. Non-visual: the Lab panel puts one in
// the row of each VM. QMP is JSON per line; the first message is the greeting
// and `qmp_capabilities` must be sent before anything else.
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: vm

    required property string name
    property string status: "unknown"   // running | paused | shutdown | unknown
    property bool ready: false

    function send(obj) {
        if (!qmp.connected)
            return;
        qmp.write(JSON.stringify(obj) + "\n");
        qmp.flush();
    }

    function pause() { send({ execute: "stop" }); }
    function resume() { send({ execute: "cont" }); }
    function powerdown() { send({ execute: "system_powerdown" }); }

    function handle(msg) {
        if (msg.QMP !== undefined) {
            send({ execute: "qmp_capabilities" });
            return;
        }
        if (msg.return !== undefined && !vm.ready) {
            vm.ready = true;
            send({ execute: "query-status" });
            return;
        }
        if (msg.return !== undefined && msg.return.status !== undefined) {
            vm.status = msg.return.status;
            return;
        }
        if (msg.event === "STOP")
            vm.status = "paused";
        if (msg.event === "RESUME")
            vm.status = "running";
        if (msg.event === "SHUTDOWN")
            vm.status = "shutdown";
    }

    Socket {
        id: qmp

        path: Quickshell.env("XDG_RUNTIME_DIR") + "/vm/" + vm.name + ".qmp"
        connected: true

        parser: SplitParser {
            onRead: function (line) {
                try {
                    vm.handle(JSON.parse(line));
                } catch (e) {
                    // SplitParser gives complete lines; a malformed response
                    // is not worth taking the panel down for.
                }
            }
        }

        onError: function (error) {
            retry.restart();
        }
    }

    Timer {
        id: retry
        interval: 1000
        onTriggered: qmp.connected = true
    }

    Timer {
        interval: 5000
        repeat: true
        running: vm.ready
        onTriggered: vm.send({ execute: "query-status" })
    }
}
