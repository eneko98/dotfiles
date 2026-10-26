// A sparkline: the last 60 samples of one series, drawn with Shape +
// PathPolyline (never Canvas), 1.5 px stroke in fg1 -- accent when
// `highlighted` (e.g. the selected series) -- and a fg0 6% fill under the
// line. No animation between samples: a new sample just replaces the path.
//
// `samples` are 0..1, oldest first. Fewer than 2 samples draws nothing.
import QtQuick
import QtQuick.Shapes

Shape {
    id: root

    property var samples: []
    property bool highlighted: false

    readonly property int max: 60
    readonly property int count: Math.min(samples.length, max)
    readonly property color lineColor: highlighted ? Theme.gold : Theme.fg1

    // The polyline path in shape coordinates: x spans the width, y is
    // inverted (0 = top). Recomputed when the samples or the size change.
    function buildPath() {
        const pts = [];
        if (count >= 2 && width > 0 && height > 0) {
            const vals = samples.slice(Math.max(0, samples.length - max));
            // Newest sample at the right edge; the empty left side fills as
            // history accumulates.
            const pad = max - count;
            for (let i = 0; i < count; i++) {
                pts.push(Qt.point((pad + i) * width / (max - 1),
                                  height - Math.max(0, Math.min(1, vals[i])) * height));
            }
        }
        return pts;
    }

    readonly property var linePts: buildPath()

    // The filled area: the line's points plus the bottom corners.
    readonly property var fillPts: {
        const pts = linePts.slice();
        if (pts.length >= 2) {
            pts.push(Qt.point(width, height));
            pts.push(Qt.point(0, height));
        }
        return pts;
    }

    ShapePath {
        strokeWidth: -1
        fillColor: Qt.rgba(Theme.fg0.r, Theme.fg0.g, Theme.fg0.b, 0.06)

        PathPolyline { path: root.fillPts }
    }

    ShapePath {
        strokeColor: root.lineColor
        strokeWidth: 1.5
        fillColor: "transparent"

        PathPolyline { path: root.linePts }
    }

    onSamplesChanged: buildPath()
    onWidthChanged: buildPath()
    onHeightChanged: buildPath()
}
