// A Nerd Font glyph with a tone instead of a colour: the state decides the
// palette slot, so no caller ever picks a colour for an icon.
//   normal    fg1   at rest
//   hover     fg0   under the pointer (bind `tone` to a hover state)
//   active    gold  the thing it represents is on / engaged
//   attention teal  the neon: something wants a look (playing, connecting)
//   alarm     red   something is wrong
//   disabled  fg2   the control is there but won't respond
//
// 14 px in the bar, 16 px in panels.
import QtQuick

Text {
    id: root

    property string glyph: ""
    property string tone: "normal"
    property int size: 14

    readonly property var tones: ({
        normal: Theme.fg1,
        hover: Theme.fg0,
        active: Theme.gold,
        attention: Theme.teal,
        alarm: Theme.red,
        disabled: Theme.fg2
    })

    text: glyph
    color: tones[tone] !== undefined ? tones[tone] : Theme.fg1
    font.family: "JetBrainsMono Nerd Font"
    font.pixelSize: size

    Behavior on color {
        ColorAnimation { duration: Motion.fast }
    }
}
