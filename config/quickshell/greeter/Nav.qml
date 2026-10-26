pragma Singleton
import QtQuick
import Quickshell

// Emulates :focus-visible. True after Tab, false after any mouse press.
Singleton {
    property bool keyboard: false
}
