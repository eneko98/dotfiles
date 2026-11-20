// Frame timing collected by FrameProbe. One stats entry per window, replaced
// wholesale on write so QML bindings re-evaluate. A probe drops its entry when
// its window hides, so a closed panel does not linger in the HUD with stale
// numbers.
pragma Singleton
import QtQuick
import Quickshell

Singleton {
    property var frameStats: ({})

    function report(name, p50, p95, maxMs) {
        const next = Object.assign({}, frameStats);
        next[name] = [p50, p95, maxMs];
        frameStats = next;
    }

    function drop(name) {
        if (frameStats[name] === undefined)
            return;
        const next = Object.assign({}, frameStats);
        delete next[name];
        frameStats = next;
    }

    function clear() {
        frameStats = ({});
    }
}
