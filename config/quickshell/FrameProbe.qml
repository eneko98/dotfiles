// A frame-timing probe for the window that contains it. Drop it inside a
// PanelWindow and give it a name; Config.hud gates both capture and reporting.
//
// FrameAnimation fires once per rendered frame, so the interval between two
// triggers is the frame time. Only the frame time of a *visible* window means
// anything: a panel that is closed is not composited, and keeping its last
// numbers would leave a closed panel in the HUD for ever.
import QtQuick
import Quickshell

Item {
    id: root

    property string name: "window"
    property var _samples: []

    readonly property bool onScreen: root.Window.window !== null
        && root.Window.window.visible

    onOnScreenChanged: {
        if (onScreen)
            return;
        root._samples = [];
        Perf.drop(root.name);
    }

    FrameAnimation {
        running: Config.hud && root.onScreen

        onTriggered: {
            // frameTime is in seconds; keep four seconds at 60 Hz.
            root._samples = root._samples
                .concat([frameTime * 1000]).slice(-240);
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: Config.hud && root.onScreen

        onTriggered: {
            if (root._samples.length === 0)
                return;
            const sorted = root._samples.slice().sort(function (a, b) {
                return a - b;
            });
            const p50 = sorted[Math.floor((sorted.length - 1) * 0.50)];
            const p95 = sorted[Math.floor((sorted.length - 1) * 0.95)];
            const maxMs = sorted[sorted.length - 1];
            Perf.report(root.name, p50, p95, maxMs);
        }
    }
}
