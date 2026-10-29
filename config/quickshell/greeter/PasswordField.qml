import QtQuick

// The password field: 360x44, with a peek button and the primary submit
// button inside. States (rest, focus, typing, busy, error, PAM prompt) are
// driven by the Auth item.
Item {
    id: field

    required property Item auth
    property bool peek: false
    // Where Tab leaves the field (the user chip) and where it comes back from
    // (Power Off). KeyNavigation inside is wired to these.
    property Item nextItem: null
    property Item previousItem: null

    readonly property bool error: auth.phase === "error"
    readonly property bool busy: auth.busy
    readonly property bool prompting: auth.phase === "prompt"
    readonly property alias inputItem: input
    readonly property alias peekItem: peekButton
    readonly property alias submitItem: submitButton

    implicitWidth: 360
    implicitHeight: 44

    function focusInput() {
        input.forceActiveFocus();
    }

    function submit() {
        if (field.busy)
            return;
        if (input.text.length === 0 && !field.prompting)
            return;
        const text = input.text;
        field.peek = false;
        field.auth.submit(text);
        if (field.prompting)
            input.text = "";
    }

    function dismiss() {
        if (field.auth.phase === "authenticating" || field.prompting) {
            field.auth.cancel();
            input.text = "";
        } else if (field.error) {
            field.auth.clearError();
        } else {
            input.text = "";
        }
    }

    // Clear on failure and when a new PAM prompt arrives.
    Connections {
        target: field.auth

        function onPhaseChanged() {
            if (field.auth.phase === "error" || field.auth.phase === "prompt")
                input.text = "";
        }
    }

    // Focus halo, outside the box.
    Rectangle {
        id: halo

        anchors.fill: box
        anchors.margins: -3
        radius: box.radius + 3
        color: "transparent"
        border.width: 3
        border.color: Qt.alpha(field.error ? Theme.red : Theme.gold, 0.18)
        opacity: input.activeFocus && !field.busy ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Motion.fast
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.standard
            }
        }
    }

    Rectangle {
        id: box

        anchors.fill: parent
        radius: 10
        color: Qt.alpha(Theme.bg0, 0.85)
        border.width: 1

        border.color: field.error ? Theme.red
                    : field.busy ? Theme.bg2
                    : input.activeFocus ? Theme.gold
                    : hover.hovered ? Theme.fg2
                    : Theme.bg2

        Behavior on border.color {
            ColorAnimation {
                duration: Motion.fast
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.standard
            }
        }
    }

    HoverHandler {
        id: hover
    }

    TextInput {
        id: input

        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.right: peekButton.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        verticalAlignment: TextInput.AlignVCenter
        activeFocusOnTab: true
        focus: true
        clip: true
        readOnly: field.busy
        echoMode: field.peek || (field.prompting && field.auth.promptEcho)
                  ? TextInput.Normal : TextInput.Password
        passwordCharacter: "•"
        passwordMaskDelay: 0
        color: field.busy ? Theme.fg1 : Theme.fg0
        selectionColor: Qt.alpha(Theme.gold, 0.35)
        selectedTextColor: Theme.fg0
        selectByMouse: true
        font.family: Config.fontSans
        font.pixelSize: 15

        KeyNavigation.tab: peekButton
        KeyNavigation.backtab: field.previousItem

        onActiveFocusChanged: CapsLock.watching = activeFocus
        onTextEdited: field.auth.clearError()

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab)
                Nav.keyboard = true;
            event.accepted = false;
        }
        Keys.onReturnPressed: field.submit()
        Keys.onEnterPressed: field.submit()
        Keys.onEscapePressed: field.escape()

        // Neon caret. Blink via opacity so it doesn't fight TextInput over `visible`.
        cursorDelegate: Rectangle {
            id: caret

            width: 2
            color: Theme.teal

            property bool shown: true

            opacity: shown && input.activeFocus && !input.readOnly ? 1 : 0

            Timer {
                interval: 530
                repeat: true
                running: input.activeFocus
                onRunningChanged: caret.shown = true
                onTriggered: caret.shown = !caret.shown
            }

            Connections {
                target: input

                function onTextChanged() {
                    caret.shown = true;
                }

                function onCursorPositionChanged() {
                    caret.shown = true;
                }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: input.text.length === 0 && input.preeditText.length === 0
            text: field.prompting ? field.auth.promptText : "Password"
            color: Theme.fg1
            font: input.font
            elide: Text.ElideRight
            width: parent.width
        }
    }

    IconButton {
        id: peekButton

        anchors.right: submitButton.left
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        glyph: field.peek ? "\uf070" : "\uf06e"   // eye-slash / eye (Font Awesome in Nerd Fonts)
        checked: field.peek
        enabled: !field.busy

        KeyNavigation.tab: submitButton
        KeyNavigation.backtab: input

        onActivated: {
            field.peek = !field.peek;
            input.forceActiveFocus();
        }
    }

    IconButton {
        id: submitButton

        anchors.right: parent.right
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        glyph: "\uf061"                            // arrow-right
        primary: true
        busy: field.busy
        enabled: !field.busy && (input.text.length > 0 || field.prompting)

        KeyNavigation.tab: field.nextItem
        KeyNavigation.backtab: peekButton

        onActivated: field.submit()
    }
}
