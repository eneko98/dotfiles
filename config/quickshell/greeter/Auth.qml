import QtQuick
import Quickshell
import Quickshell.Services.Greetd

// Wraps the greetd conversation. Phases: idle | authenticating | prompt | error | launching
Item {
    id: auth

    property string user: Config.defaultUser
    property string phase: "idle"
    property string message: ""       // error, info or launching text
    property bool messageIsError: false
    property string promptText: ""
    property bool promptEcho: false

    // Password typed before greetd asked for it. Cleared as soon as it is sent.
    property string pendingSecret: ""

    readonly property bool busy: phase === "authenticating" || phase === "launching"

    function submit(text) {
        if (busy)
            return;
        if (phase === "prompt") {
            phase = "authenticating";
            if (Config.demo)
                demoTimer.restart();
            else
                Greetd.respond(text);
            return;
        }
        clearMessage();
        pendingSecret = text;
        phase = "authenticating";
        if (Config.demo) {
            demoTimer.restart();
            return;
        }
        if (!Greetd.available) {
            fail("Login service unavailable.");
            return;
        }
        Greetd.createSession(user);
    }

    function cancel() {
        if (phase === "launching")
            return;
        endSession();
        clearMessage();
        phase = "idle";
    }

    function clearError() {
        if (phase !== "error")
            return;
        clearMessage();
        phase = "idle";
    }

    function fail(text) {
        endSession();
        message = text && text.length > 0 ? text : "Wrong password. Try again.";
        messageIsError = true;
        phase = "error";
    }

    function launch() {
        phase = "launching";
        message = "Starting " + Config.sessionName + "…";
        messageIsError = false;
        if (Config.demo)
            quitTimer.restart();
        else
            Greetd.launch(Config.sessionCommand);
    }

    function endSession() {
        pendingSecret = "";
        promptText = "";
        promptEcho = false;
        if (!Config.demo && Greetd.state !== GreetdState.Inactive)
            Greetd.cancelSession();
    }

    function clearMessage() {
        message = "";
        messageIsError = false;
    }

    Connections {
        target: Greetd
        enabled: !Config.demo

        function onAuthMessage(message, error, responseRequired, echoResponse) {
            if (!responseRequired) {
                auth.message = message;
                auth.messageIsError = error;
                return;
            }
            if (auth.pendingSecret !== "" && !echoResponse) {
                const secret = auth.pendingSecret;
                auth.pendingSecret = "";
                Greetd.respond(secret);
                return;
            }
            auth.promptText = message;
            auth.promptEcho = echoResponse;
            auth.phase = "prompt";
        }

        function onAuthFailure(message) {
            auth.fail(message);
        }

        function onReadyToLaunch() {
            auth.launch();
        }

        function onError(error) {
            auth.fail(error);
        }
    }

    Timer {
        id: demoTimer
        interval: 600
        onTriggered: {
            const ok = auth.pendingSecret === "demo";
            auth.pendingSecret = "";
            if (ok)
                auth.launch();
            else
                auth.fail("");
        }
    }

    Timer {
        id: quitTimer
        interval: 1000
        onTriggered: Qt.quit()
    }
}
