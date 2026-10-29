// Motion tokens. Every animation in the shell picks from here, so the whole
// bar shares one sense of time and one family of curves instead of a scatter
// of magic numbers.
//
// Durations map to intent, not to widgets:
//   press   80  a state flip, too fast to watch
//   fast   120  hover, a colour change
//   base   180  a normal transition
//   medium 240  geometry the eye should follow (a width slide)
//   slow   320  a full panel arriving
//   fade   120  a pure cross-fade
//
// Interaction waits are not durations; they are not zeroed by reduced motion:
//   stagger   40  step between two staggered items (max two steps)
//   hoverIn  150  wait before expanding on hover
//   hoverOut 300  wait before collapsing after hover
//   tooltip  500  wait before showing a tooltip
//
// Curves are control-point lists for Easing.BezierSpline (x1,y1,x2,y2 plus the
// mandatory 1,1 end). `standard` is a gentle ease-in-out for things that move
// on the spot, `decel` for things arriving, `accel` for things leaving, `snap`
// for the overview release (the only deliberate overshoot), and `fling` for
// every other gesture release.
//
// `reduced` follows Config (persisted, set through the `bar` IPC): durations
// collapse to 0 (instant cuts) except fades. `QS_MOTION_SCALE` slows the whole
// system down for inspection; it is read from the environment and never set
// in the service.
pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root

    property bool reduced: false

    // Slow motion for inspection only. Never set in the service.
    readonly property real debugScale: Number(Quickshell.env("QS_MOTION_SCALE")) || 1
    readonly property real k: reduced ? 0 : debugScale

    readonly property int press: 80 * k
    readonly property int fast: 120 * k
    readonly property int base: 180 * k
    readonly property int medium: 240 * k
    readonly property int slow: 320 * k

    // The one duration that survives reduced motion: a cut is harsher than a
    // short fade for anything that only changes opacity.
    readonly property int fade: reduced ? 80 : 120 * debugScale

    // Interaction waits, not animations: not zeroed by reduced motion.
    readonly property int stagger: reduced ? 0 : 40 * debugScale
    readonly property int hoverIn: 150
    readonly property int hoverOut: 300
    readonly property int tooltip: 500

    readonly property var standard: [0.2, 0.0, 0.0, 1.0, 1.0, 1.0]
    readonly property var decel: [0.05, 0.7, 0.1, 1.0, 1.0, 1.0]
    readonly property var accel: [0.3, 0.0, 0.8, 0.15, 1.0, 1.0]
    // Gesture release, overview snap only. Peak overshoot ~1.6 % around 80 %.
    // Initial slope 4.
    readonly property var snap: [0.25, 1.0, 0.5, 1.06, 1.0, 1.0]
    // Gesture release without overshoot (swipes, calendar). Initial slope 2.
    readonly property var fling: [0.3, 0.6, 0.6, 1.0, 1.0, 1.0]
    readonly property real snapSlope: 4
    readonly property real flingSlope: 2

    // Release duration so the animation starts at the finger's speed.
    // distance in px, velocity in px/ms.
    function release(distance, velocity, slope, lo, hi) {
        if (reduced)
            return 0;
        const v = Math.max(Math.abs(velocity), 0.05);
        const d = slope * Math.abs(distance) / v;
        return Math.round(Math.min(hi, Math.max(lo, d)) * debugScale);
    }

    // Duration for an animation reversed part-way. progress in [0, 1].
    function reverse(full, progress) {
        if (reduced)
            return 0;
        return Math.max(press, Math.round(full * progress));
    }
}
