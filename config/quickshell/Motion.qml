// Motion tokens. Every animation in the shell picks from here, so the whole
// bar shares one sense of time and one family of curves instead of a scatter
// of magic numbers.
//
// Durations map to intent, not to widgets:
//   press  80  a state flip, too fast to watch
//   fast  120  hover, a colour change
//   base  180  a normal transition
//   medium 240  geometry the eye should follow (a width slide)
//   slow  320  a full panel arriving
//
// Curves are control-point lists for Easing.BezierSpline (x1,y1,x2,y2 plus the
// mandatory 1,1 end). `standard` is a gentle ease-in-out for things that move
// on the spot, `decel` for things arriving, `accel` for things leaving; the
// close of a transition is roughly 0.7x its open, which falls out of the
// duration choice rather than a separate curve.
//
// `reduced` follows Config (persisted, set through the `bar` IPC): every
// duration here collapses to 0 (instant cuts) except the fades -- opacity
// keeps a short fade, which is what the accessibility guidelines recommend.
pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root

    property bool reduced: false

    readonly property int press: root.reduced ? 0 : 80
    readonly property int fast: root.reduced ? 0 : 120
    readonly property int base: root.reduced ? 0 : 180
    readonly property int medium: root.reduced ? 0 : 240
    readonly property int slow: root.reduced ? 0 : 320

    // The one duration that survives reduced motion: a cut is harsher than a
    // short fade for anything that only changes opacity.
    readonly property int fade: root.reduced ? 80 : 120

    readonly property var standard: [0.2, 0.0, 0.0, 1.0, 1.0, 1.0]
    readonly property var decel: [0.05, 0.7, 0.1, 1.0, 1.0, 1.0]
    readonly property var accel: [0.3, 0.0, 0.8, 0.15, 1.0, 1.0]
    // A slight overshoot for playful geometry (the island growing). The Y of
    // the first control point goes above 1; the eye reads it as elasticity.
    readonly property var spring: [0.34, 1.3, 0.64, 1.0, 1.0, 1.0]
}
