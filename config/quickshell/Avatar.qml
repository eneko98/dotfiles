// A circular avatar drawn with Canvas 2D. QML's clip ignores radius and the
// shader/effect routes do not render inside Quickshell, so this clips a
// circular path and paints the image into it. The canvas reloads and repaints
// whenever the source URL changes.
import QtQuick

Item {
    id: root

    property string source: ""
    property real size: 16
    // Square avatars (notifications) are drawn as they are. A video thumbnail
    // is 16:9: with `cover` it is centred and cropped instead of squashed into
    // the circle. Needs the intrinsic size, which only an Image knows.
    property bool cover: false

    Image {
        id: probe
        source: root.source
        visible: false
        asynchronous: true
        onStatusChanged: canvas.requestPaint()
    }

    width: size
    height: size

    Canvas {
        id: canvas
        anchors.fill: parent

        property string imageUrl: root.source

        onImageUrlChanged: {
            if (imageUrl.length > 0)
                loadImage(imageUrl);
        }

        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            if (imageUrl.length === 0)
                return;

            ctx.save();
            ctx.beginPath();
            ctx.arc(width / 2, height / 2, width / 2, 0, 2 * Math.PI);
            ctx.closePath();
            ctx.clip();

            if (root.cover && probe.sourceSize.width > 0
                && probe.sourceSize.height > 0) {
                const scale = Math.max(width / probe.sourceSize.width,
                    height / probe.sourceSize.height);
                const dw = probe.sourceSize.width * scale;
                const dh = probe.sourceSize.height * scale;
                ctx.drawImage(imageUrl, (width - dw) / 2, (height - dh) / 2,
                    dw, dh);
            } else {
                ctx.drawImage(imageUrl, 0, 0, width, height);
            }

            ctx.restore();
        }

        Component.onCompleted: {
            if (imageUrl.length > 0)
                loadImage(imageUrl);
        }

        onImageLoaded: requestPaint()
    }
}
