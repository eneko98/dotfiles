// Keyboard vs mouse focus, a global :focus-visible. Focus rings are only
// drawn while `keyboard` is true: Tab sets it, any mouse press clears it, so
// clicking never leaves a ring behind and tabbing always shows one.
//
// Components bind their ring to `activeFocus && Nav.keyboard`. A tiny helper
// keeps the pair consistent: call `touched()` from a focus change and
// `mouse()` from a press.
pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root

    property bool keyboard: false

    function mouse() {
        root.keyboard = false;
    }

    function tab() {
        root.keyboard = true;
    }
}
