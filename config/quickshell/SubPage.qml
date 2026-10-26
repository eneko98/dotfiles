// A page that pushes in from the right over a panel's content: x from +24 to
// 0 and opacity, Motion.medium on the decel curve; Escape or `back()` returns
// with Motion.base on the accel curve. The owner anchors it over the panel
// (usually `anchors.fill: parent`) and connects `back()` to its pop logic.
//
// Content lands in a Column with the panel's padding; the header is "‹ Back"
// plus the title. The page takes focus when active so Escape works.
import QtQuick

Item {
    id: root

    property bool active: false
    property string title: ""

    signal back()

    default property alias content: pageCol.data

    x: root.active ? 0 : 24
    opacity: root.active ? 1 : 0
    visible: root.active || xAnim.running || opacityAnim.running

    onFocusChanged: if (focus && !root.active) root.active = true

    // Enter: medium + decel. Leave: base + accel. Two explicit runs because a
    // Behavior cannot switch curve by direction.
    NumberAnimation {
        id: xAnim
        target: root; property: "x"; to: root.active ? 0 : 24
        duration: root.active ? Motion.medium : Motion.base
        easing.type: Easing.BezierSpline
        easing.bezierCurve: root.active ? Motion.decel : Motion.accel
    }
    NumberAnimation {
        id: opacityAnim
        target: root; property: "opacity"; to: root.active ? 1 : 0
        duration: root.active ? Motion.medium : Motion.base
        easing.type: Easing.BezierSpline
        easing.bezierCurve: root.active ? Motion.decel : Motion.accel
    }
    onActiveChanged: {
        xAnim.stop();
        opacityAnim.stop();
        xAnim.start();
        opacityAnim.start();
        if (root.active)
            root.forceActiveFocus();
    }

    Keys.onEscapePressed: root.back()

    // The page's own backing: it must hide the content underneath while it
    // is up. Fully opaque -- 97% lets the covered section bleed through
    // enough to read, and a page is a page.
    Rectangle {
        anchors.fill: parent
        radius: Tokens.radius.panel
        color: Theme.bg1
    }

    Column {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Tokens.space.m
        spacing: Tokens.space.s

        Pressable {
            width: backText.implicitWidth + Tokens.space.s * 2
            height: 24

            onClicked: root.back()

            Row {
                anchors.centerIn: parent
                spacing: Tokens.space.xs

                Text {
                    id: backText
                    text: "‹"
                    color: Theme.fg1
                    font.family: "Adwaita Sans"
                    font.pixelSize: 14
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.title
                    color: Theme.fg0
                    font.family: "Adwaita Sans"
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                }
            }
        }
    }

    Column {
        id: pageCol
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.topMargin: Tokens.space.s
    }
}
