// A notification avatar. A true circular clip is not achievable here:
// QML's clip ignores radius, Qt5Compat.GraphicalEffects is not available
// inside Quickshell, MultiEffect's maskSource does not render, and a custom
// .qsb shader is not drawn either (all measured). The result is a rounded
// square; the design's circle is the one concession left open.
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
