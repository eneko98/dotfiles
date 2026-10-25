// The power button: a glyph that opens the session menu (lock / log out /
// suspend / reboot / power off), the same fuzzel menu SUPER + Escape runs.
//
// execDetached does not pass its arguments through a shell, and the script is a
// shell script, so it is started as `sh -c "$HOME/..."`: that way the shell
// expands $HOME and no repo path is hardcoded.

import Quickshell
import QtQuick

Row {
    id: root

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: ""
        color: Theme.fg1
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 14
    }

    TapHandler {
        onTapped: Quickshell.execDetached(["sh", "-c", "$HOME/.config/hypr/scripts/session-menu"])
    }
}
