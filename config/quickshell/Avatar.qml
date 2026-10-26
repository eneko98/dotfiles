// A notification avatar. A true circular clip would need either
// Qt5Compat.GraphicalEffects (not available inside Quickshell) or a
// precompiled .qsb shader (Qt 6 dropped inline shader strings), so this is a
// rounded square: the design's circle is the one concession left open.
import QtQuick

Rectangle {
    id: root

    property string source: ""
    property real size: 16

    width: size
    height: size
    radius: 4
    color: Theme.bg2
    clip: true

    Image {
        anchors.fill: parent
        source: root.source
        sourceSize.width: Math.round(root.size * 2)
        sourceSize.height: Math.round(root.size * 2)
        fillMode: Image.PreserveAspectCrop
    }
}
