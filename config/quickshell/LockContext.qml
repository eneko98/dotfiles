// Authentication state shared by the lock surfaces (there is one per screen).
//
// The PAM flow is the one from the Quickshell lockscreen example: start() when
// the user submits, respond() when PAM asks for the password, completed() either
// unlocks or flags a failure. `currentText` lives here, not in each surface, so
// every screen shows the same field.
//
// configDirectory is relative to this file, so the password check uses
// config/quickshell/pam/password.conf (`auth required pam_unix.so`) instead of
// /etc/pam.d/login, whose prompts are written for a text login.

import QtQuick
import Quickshell
import Quickshell.Services.Pam

Scope {
    id: root

    signal unlocked()

    property string currentText: ""
    property bool unlockInProgress: false
    property bool showFailure: false
    // Set while the unlock animation plays; the surface fades out and the lock
    // is only released when the timer fires.
    property bool dismissing: false

    onCurrentTextChanged: showFailure = false

    function tryUnlock() {
        if (currentText === "" || unlockInProgress)
            return;

        unlockInProgress = true;
        pam.start();
    }

    PamContext {
        id: pam

        configDirectory: "pam"
        config: "password.conf"

        onPamMessage: {
            if (pam.responseRequired)
                pam.respond(root.currentText);
        }

        onCompleted: function (result) {
            if (result === PamResult.Success) {
                // Keep unlockInProgress true: the field stays disabled while
                // the exit animation plays.
                root.currentText = "";
                root.dismissing = true;
                dismissTimer.start();
                return;
            }

            root.currentText = "";
            root.showFailure = true;
            root.unlockInProgress = false;
        }
    }

    Timer {
        id: dismissTimer
        interval: 240
        onTriggered: root.unlocked()
    }
}
