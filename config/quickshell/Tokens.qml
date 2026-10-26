// Layout and depth tokens. Spacing is a 4 px scale; radius has three voices
// (the panel pill, a section card, a small control); elevation has three
// levels, each a bag of numbers that Surface.qml turns into fill, hairline
// and shadow.
//
// The elevation recipe per level:
//   fill       alpha over the wallpaper while Hyprland blur is on
//   fillSolid  the flat fallback while it is not (the default today)
//   stroke     the hairline on the edge, fg0 at low alpha
//   highlight  the 1 px line just inside the top edge, as if lit from above
//   shadow*    the drop shadow's blur, y offset and alpha
//
// Hover raises one level instead of swapping a colour: that is what makes the
// chrome read as physical rather than as buttons that light up.
//
// `blur` stays false until the cost is measured and the Hyprland layer rules
// (quickshell-bar / quickshell-stage namespaces) are added on purpose.
pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root

    readonly property var space: ({ xs: 4, s: 8, m: 12, l: 16, xl: 24 })

    readonly property var radius: ({ panel: 18, card: 12, control: 8 })

    readonly property var e1: ({ fill: 0.78, fillSolid: 0.90, stroke: 0.06, highlight: 0.05, shadowBlur: 12, shadowY: 2, shadowAlpha: 0.35 })
    readonly property var e2: ({ fill: 0.86, fillSolid: 0.94, stroke: 0.07, highlight: 0.06, shadowBlur: 16, shadowY: 3, shadowAlpha: 0.40 })
    readonly property var e3: ({ fill: 0.92, fillSolid: 0.97, stroke: 0.06, highlight: 0.05, shadowBlur: 32, shadowY: 12, shadowAlpha: 0.50 })

    // Hyprland applies blur per layer namespace; these are the ones the shell
    // uses, so the layer rules and the QML stay in sync by construction.
    readonly property var ns: ({ bar: "quickshell-bar", stage: "quickshell-stage", osd: "quickshell-osd" })

    function level(n, hovered) {
        if (n >= 3) return e3;
        if (n === 2) return hovered ? e3 : e2;
        return hovered ? e2 : e1;
    }
}
