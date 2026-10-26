pragma Singleton
import QtQuick
import Quickshell

Singleton {
    readonly property string defaultUser: "eneko98"
    readonly property string sessionName: "Hyprland"

    // Must match Exec= of the "Hyprland (uwsm-managed)" session entry, so the
    // session greetd starts is the same systemd user session we had before.
    readonly property var sessionCommand: ["uwsm", "start", "-e", "-D", "Hyprland", "hyprland.desktop"]
    readonly property var rebootCommand: ["systemctl", "reboot"]
    readonly property var poweroffCommand: ["systemctl", "poweroff"]

    readonly property string background: "/usr/share/backgrounds/greeter.png"
    readonly property string fontSans: "Adwaita Sans"
    readonly property string fontIcons: "JetBrainsMono Nerd Font"

    // Demo mode: fake greetd. "demo" logs in, anything else fails.
    readonly property bool demo: Quickshell.env("GREETER_DEMO") === "1"
    // Force the Caps Lock warning on in demo mode.
    readonly property bool demoCaps: Quickshell.env("GREETER_DEMO_CAPS") === "1"
}
