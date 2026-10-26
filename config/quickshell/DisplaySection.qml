// Display: the brightness row (glyph, slider, percentage) and the night
// light tile. Brightness goes through the Brightness singleton -- the same
// source the OSD reads; the tile is the hyprsunset toggle.
import QtQuick

Column {
    id: root

    // The System panel shows the night light tile in its grid instead; used
    // standalone, the section carries it.
    property bool showNightTile: true

    width: parent.width
    spacing: Tokens.space.s

    Item {
        width: parent.width
        height: 32

        // The same 28px leading slot the sound row gives its mute button,
        // so both sliders start (and end) at the same x.
        Item {
            id: sunSlot
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 28
            height: 28

            Glyph {
                anchors.centerIn: parent
                glyph: "󰃠"
                size: 15
            }
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 34
            horizontalAlignment: Text.AlignRight
            text: Brightness.percent + "%"
            color: Theme.fg1
            font.family: "Adwaita Sans"
            font.pixelSize: 11
            font.features: ({ "tnum": 1 })
        }

        Slider {
            anchors.left: sunSlot.right
            anchors.leftMargin: Tokens.space.s
            anchors.right: parent.right
            anchors.rightMargin: 74
            anchors.verticalCenter: parent.verticalCenter
            value: Brightness.percent / 100

            onMoved: function (value) {
                Brightness.set(value);
            }
        }
    }

    ToggleTile {
        visible: root.showNightTile
        checked: NightLight.on
        glyph: NightLight.on ? "󰖔" : "󰖔"
        title: "Night light"
        subtitle: NightLight.on ? "4000 K" : "Off"

        onToggled: NightLight.toggle()
    }
}
