// The processes page, pushed as a SubPage. Twelve rows: name, a 48x4 usage
// bar (accent on the selected row, fg1 otherwise), cpu% and memory tabular,
// and End -- a ConfirmButton, visible on hover or focus. The cpu figure is
// the share of the WHOLE machine's cpu (all rows sum to <= 100%), which the
// header tooltip says out loud. Sorting is by cpu or memory; the reorder
// itself does not animate; the selection follows the key (pid or name).
//
// Sampling runs only while the page is visible: Processes.active follows it.
import QtQuick

Column {
    id: root

    width: parent.width
    spacing: Tokens.space.xs

    onVisibleChanged: Processes.active = visible
    Component.onCompleted: Processes.active = Processes.active || visible

    property int selected: 0

    function moveSelection(delta) {
        if (Processes.rows.length === 0)
            return;
        root.selected = Math.max(0,
            Math.min(Processes.rows.length - 1, root.selected + delta));
    }

    Keys.onPressed: function (event) {
        if (event.key === Qt.Key_Down) {
            root.moveSelection(1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Up) {
            root.moveSelection(-1);
            event.accepted = true;
        }
    }

    // --- The toggles row --------------------------------------------------
    Item {
        width: parent.width
        height: 26

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: Tokens.space.xs

            SortToggle {
                label: "CPU"
                on: Processes.sortBy === "cpu"
                onClicked: Processes.sortBy = "cpu"
            }
            SortToggle {
                label: "Memory"
                on: Processes.sortBy === "mem"
                onClicked: Processes.sortBy = "mem"
            }
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Tokens.space.xs

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Group by app"
                color: Theme.fg1
                font.family: "Adwaita Sans"
                font.pixelSize: 11
            }

            SortToggle {
                label: Processes.grouped ? "On" : "Off"
                on: Processes.grouped
                onClicked: Processes.grouped = !Processes.grouped
            }
        }
    }

    component SortToggle: Pressable {
        id: sortToggle

        property string label: ""
        property bool on: false

        width: sortLabel.implicitWidth + Tokens.space.s * 2
        height: 22

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: sortToggle.on
                ? Qt.rgba(Theme.gold.r, Theme.gold.g, Theme.gold.b, 0.18)
                : "transparent"
            border.width: 1
            border.color: sortToggle.on ? "transparent" : Theme.bg2
        }

        Text {
            id: sortLabel
            anchors.centerIn: parent
            text: sortToggle.label
            color: sortToggle.on ? Theme.gold : Theme.fg1
            font.family: "Adwaita Sans"
            font.pixelSize: 11
        }
    }

    // --- The rows ---------------------------------------------------------
    Repeater {
        model: Processes.rows

        delegate: Item {
            id: row

            required property var modelData
            readonly property bool isSelected: index === root.selected

            width: root.width
            height: 36

            // The row background: click selects, hover feeds both the tint
            // and the End button's visibility. Declared FIRST so the End
            // button (later = on top) receives its own clicks.
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.ArrowCursor
                onClicked: root.selected = index
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: Tokens.radius.control
                color: row.isSelected ? Theme.bg2 : (row.hovered ? Theme.bg2 : "transparent")
                opacity: 0.6
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: Tokens.space.s
                anchors.right: cpuLabel.left
                anchors.verticalCenter: parent.verticalCenter
                text: row.modelData.name
                color: Theme.fg0
                font.family: "Adwaita Sans"
                font.pixelSize: 13
                elide: Text.ElideRight
            }

            // The usage bar: 48x4, of the row's metric.
            Rectangle {
                anchors.right: cpuLabel.left
                anchors.rightMargin: Tokens.space.s
                anchors.verticalCenter: parent.verticalCenter
                width: 48
                height: 4
                radius: 2
                color: Theme.bg2

                Rectangle {
                    width: parent.width * Math.min(1,
                        Processes.sortBy === "mem"
                            ? row.modelData.rssBytes / (Resources.memTotalGiB * 1073741824)
                            : row.modelData.cpu)
                    height: parent.height
                    radius: 2
                    color: row.isSelected ? Theme.gold : Theme.fg1
                }
            }

            Text {
                id: cpuLabel

                anchors.right: memLabel.left
                anchors.rightMargin: Tokens.space.s
                anchors.verticalCenter: parent.verticalCenter
                text: (row.modelData.cpu * 100).toFixed(0) + "%"
                color: Theme.fg1
                font.family: "Adwaita Sans"
                font.pixelSize: 12
                font.features: ({ "tnum": 1 })
            }

            Text {
                id: memLabel

                anchors.right: endButton.left
                anchors.rightMargin: Tokens.space.s
                anchors.verticalCenter: parent.verticalCenter
                text: row.modelData.rssBytes >= 1073741824
                    ? (row.modelData.rssBytes / 1073741824).toFixed(1) + " GB"
                    : Math.round(row.modelData.rssBytes / 1048576) + " MB"
                color: Theme.fg1
                font.family: "Adwaita Sans"
                font.pixelSize: 12
                font.features: ({ "tnum": 1 })
            }

            // End: a two-step kill, visible on hover or when the row is
            // selected (keyboard path).
            ConfirmButton {
                id: endButton

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 52
                height: 24
                visible: row.modelData.canEnd && (row.hovered || row.isSelected)
                label: "End"
                confirmText: "End " + row.modelData.name + "?"
                armedMs: 3000

                onConfirmed: Processes.end(row.modelData)
            }
        }
    }

    Text {
        visible: Processes.rows.length === 0
        text: "Sampling…"
        color: Theme.fg2
        font.family: "Adwaita Sans"
        font.pixelSize: 12
    }
}
