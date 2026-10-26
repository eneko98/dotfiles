// The session actions: five 40x40 buttons with tooltips. Lock and Suspend
// act on the first press (nothing destructive in them); Log out, Reboot and
// Power Off are ConfirmButtons, so red only shows when the action is
// actually about to run. The commands match the session menu's mappings.
import QtQuick
import Quickshell

Row {
    id: root

    width: parent.width
    spacing: Tokens.space.s

    // The two immediate actions: the same ghost pill shape the ConfirmButton
    // rests in, minus the two-step.
    component ImmediatePill: Pressable {
        id: pill

        property string label: ""
        property string glyph: ""
        property string command: ""

        // Same as ConfirmButton: keep the hit area full-size.
        pressScale: 1.0

        width: 40
        height: 40

        onClicked: Quickshell.execDetached(["sh", "-c", command])

        Rectangle {
            anchors.fill: parent
            radius: parent.height / 2
            color: Qt.rgba(Theme.bg1.r, Theme.bg1.g, Theme.bg1.b, 0.70)
            border.width: 1
            border.color: Qt.rgba(Theme.gold.r, Theme.gold.g, Theme.gold.b, 0.30)
        }

        Glyph {
            anchors.centerIn: parent
            glyph: pill.glyph
            tone: pill.hovered ? "hover" : "normal"
            size: 15
        }

        Tooltip {
            hovered: pill.hovered
            label: pill.label
            below: false
            anchors.bottom: parent.top
            anchors.bottomMargin: Tokens.space.xs
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    ImmediatePill {
        label: "Lock"
        glyph: "󰌾"
        command: "sh -c $HOME/.config/hypr/scripts/lock"
    }

    ImmediatePill {
        label: "Suspend"
        glyph: "󰤄"
        command: "systemctl suspend"
    }

    ConfirmButton {
        width: 40
        height: 40
        showLabel: false
        label: "Log out"
        glyph: "󰿅"
        confirmText: "Click again to log out"

        onConfirmed: Quickshell.execDetached(["uwsm", "stop"])
    }

    ConfirmButton {
        width: 40
        height: 40
        showLabel: false
        label: "Reboot"
        glyph: "󰜉"
        confirmText: "Click again to reboot"

        onConfirmed: Quickshell.execDetached(["systemctl", "reboot"])
    }

    ConfirmButton {
        width: 40
        height: 40
        showLabel: false
        label: "Power Off"
        glyph: "\uf011"
        confirmText: "Click again to power off"

        onConfirmed: Quickshell.execDetached(["systemctl", "poweroff"])
    }
}
