// The desktop widgets, managed in one place: a master switch (show them at
// all) and one row per widget, so any of them can be taken off the wallpaper
// without touching a config file.
//
// The list is a table: adding a widget is one entry here plus its instance in
// shell.qml (and the Config pair its Widget reads). The toggles do not close
// the panel -- you are managing, and the effect is visible behind it when the
// desktop shows.
import QtQuick

Item {
    id: root

    implicitHeight: column.implicitHeight

    // The catalogue. `id` is the Widget's widgetId; `on` is the Config pair a
    // Widget reads (flat keys, the pattern of every persisted property here).
    readonly property var entries: [
        {
            id: "fetch",
            glyph: "\uf2db",
            title: "Fetch",
            subtitle: "System · live"
        },
        {
            id: "vinyl",
            glyph: "\uf001",
            title: "Vinyl",
            subtitle: "Now playing"
        }
    ]

    Column {
        id: column

        width: parent.width
        spacing: Tokens.space.s

        // The master switch: what "show me the bare wallpaper" means today.
        ToggleTile {
            width: column.width
            tileWidth: column.width
            expandable: false
            glyph: "\uf108"
            title: "Desktop widgets"
            subtitle: "All of them"
            checked: Config.desktopWidgets
            onToggled: Config.toggleDesktopWidgets()
        }

        // An index model, not the array: the delegates are created once and
        // their bindings re-read the entry (a var-array model is replaced on
        // every change, which rebuilds every delegate).
        Repeater {
            model: root.entries.length

            delegate: ToggleTile {
                id: tile

                required property int index

                readonly property var entry: root.entries[index]

                width: column.width
                tileWidth: column.width
                expandable: false
                glyph: tile.entry.glyph
                title: tile.entry.title
                subtitle: tile.entry.subtitle
                checked: Config.widgetEnabled(tile.entry.id)

                // Invert the SOURCE, not `checked`: at this moment `checked`
                // still has the old value (ToggleTile only emits toggled()).
                onToggled: Config.toggleWidget(tile.entry.id)
            }
        }
    }
}
