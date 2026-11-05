pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Greetd
import "../config"
import "../theme"
import "../artifacts"
import "../components"
PanelWindow {
    id: root
    property var sessions: []
    property int sessionIndex: 0
    property var command: []
    property string desktopName: ""
    property string authenticationError: ""
    property string message: ""
    property bool responseRequired: false
    property bool echoResponse: false
    property bool authenticated: false
    property bool launchSent: false
    property bool opened: false
    property bool skipMotion: false
    property real progress: opened ? 1 : 0
    readonly property real paperWidth: Math.min(Settings.launcherWidth, width - 32)
    readonly property real paperHeight: Math.min(520, height - 48)
    readonly property real leftEdge: (width - paperWidth) / 2
    readonly property real rightEdge: leftEdge + paperWidth
    readonly property real rollPosition: width + 32 - (width + 32 - leftEdge) * progress
    readonly property bool authenticating: Greetd.state === GreetdState.Authenticating
    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "illuminated-greeter"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore
    color: Settings.color("environment")
    Behavior on progress { NumberAnimation { duration: root.skipMotion ? 0 : Motion.greeter; easing.type: Motion.easing } }
    Component.onCompleted: { opened = true; Qt.callLater(function() { username.forceActiveFocus(); }); }
    function clearSecret() { response.clear(); responseRequired = false; }
    function begin() {
        if (progress < .99 || !Greetd.available || !sessions[sessionIndex] || !username.text.trim() || authenticating || authenticated) return;
        command = sessions[sessionIndex].command.slice(); desktopName = sessions[sessionIndex].desktop;
        clearSecret(); authenticationError = ""; message = "Authenticating…"; Greetd.createSession(username.text.trim()); authTimeout.restart();
    }
    function answer() {
        if (!responseRequired) return;
        const answer = response.text;
        response.clear(); responseRequired = false;
        Greetd.respond(answer);
    }
    function cancel() {
        if (launchSent) return;
        clearSecret(); authTimeout.stop(); launchWatchdog.stop(); authenticated = false; launchSent = false;
        Greetd.cancelSession(); opened = true; message = "Authentication cancelled"; Qt.callLater(function() { username.forceActiveFocus(); });
    }
    function launchNow() {
        if (!authenticated || launchSent || Greetd.state !== GreetdState.ReadyToLaunch) return;
        launchSent = true; launchWatchdog.stop();
        // greetd expects prompt greeter exit after start_session; animation is already complete.
        Greetd.launch(command, ["XDG_SESSION_TYPE=wayland", "XDG_CURRENT_DESKTOP=" + desktopName]);
    }
    function bypassMotion() { skipMotion = true; progress = opened ? 1 : 0; progress = Qt.binding(function() { return root.opened ? 1 : 0; }); }
    onProgressChanged: if (progress <= .001 && authenticated) launchNow()
    Connections {
        target: Greetd
        function onAuthMessage(text, error, required, echo) {
            root.message = text; root.echoResponse = echo; root.responseRequired = required; response.clear();
            if (required) Qt.callLater(function() { response.forceActiveFocus(); });
        }
        function onAuthFailure(text) { root.clearSecret(); authTimeout.stop(); root.authenticated = false; root.authenticationError = text || "Authentication failed"; root.message = root.authenticationError; root.opened = true; Qt.callLater(function() { username.forceActiveFocus(); }); }
        function onReadyToLaunch() { root.clearSecret(); authTimeout.stop(); root.authenticated = true; root.opened = false; launchWatchdog.restart(); }
        function onError(text) { root.clearSecret(); root.authenticated = false; root.launchSent = false; launchWatchdog.stop(); authTimeout.stop(); root.message = root.authenticationError || text || "Session could not start"; root.opened = true; Qt.callLater(function() { username.forceActiveFocus(); }); }
    }
    Timer { id: authTimeout; interval: Settings.option("greeter.authTimeout"); onTriggered: { root.cancel(); root.message = "Authentication timed out. Retry or use the text-login fallback."; } }
    Timer { id: launchWatchdog; interval: Math.max(1000, Motion.greeter + 500); onTriggered: root.launchNow() }
    Process {
        command: ["python3", Quickshell.shellPath("greeter/sessions.py")].concat(Quickshell.env("ILLUMINATED_GREETER_TEST") === "1" ? ["--fixtures", "--directory", Quickshell.env("ILLUMINATED_GREETER_SESSION_DIR")] : [])
        running: true
        stdout: StdioCollector { onStreamFinished: { try { root.sessions = JSON.parse(text); if (!root.sessions.length) root.message = "No trusted installed Hyprland or Mango sessions found."; } catch (e) { root.message = "Session discovery failed"; } } }
    }
    Shortcut { sequence: "F2"; onActivated: root.bypassMotion() }
    Shortcut { sequence: "Escape"; onActivated: if (root.authenticating || root.authenticated) root.cancel() }
    Item {
        y: (root.height - root.paperHeight) / 2
        x: Math.min(root.rightEdge, root.rollPosition)
        width: Math.max(0, root.rightEdge - root.rollPosition)
        height: root.paperHeight
        clip: true
        Item {
            x: root.leftEdge - parent.x
            width: root.paperWidth; height: root.paperHeight
            Paper { anchors.fill: parent }
            ColumnLayout {
                anchors.fill: parent; anchors.margins: 24; spacing: Theme.gap
                InkLabel { text: "The Illuminated Desktop"; font.pixelSize: Settings.option("typography.heading"); Layout.fillWidth: true }
                InkLabel { text: "Welcome to the Herbarium"; color: Theme.accent }
                ComboBox { Layout.fillWidth: true; model: root.sessions; textRole: "name"; currentIndex: root.sessionIndex; enabled: !root.authenticating && !root.authenticated; onActivated: root.sessionIndex = currentIndex }
                SearchField { id: username; objectName: "greeter-user"; Layout.fillWidth: true; placeholderText: "Username"; enabled: !root.authenticating && !root.authenticated; onAccepted: root.begin(); Accessible.name: "Username" }
                InkLabel { text: root.message || (root.sessions.length ? "Select a session and enter your username." : "Trusted session metadata unavailable; inspect the greeter setup."); Layout.fillWidth: true }
                SearchField { id: response; objectName: "greeter-response"; Layout.fillWidth: true; visible: root.responseRequired; echoMode: root.echoResponse ? TextInput.Normal : TextInput.Password; onAccepted: root.answer(); Accessible.name: root.echoResponse ? "Authentication response" : "Secret authentication response" }
                RowLayout {
                    ActionButton { text: root.responseRequired ? "Respond" : "Log in"; enabled: Greetd.available && root.sessions.length > 0 && root.progress > .99 && !root.authenticated; onClicked: { if (root.responseRequired) root.answer(); else root.begin(); } }
                    ActionButton { text: "Cancel"; visible: root.authenticating || root.authenticated; onClicked: root.cancel() }
                    ActionButton { text: "Skip motion (F2)"; onClicked: root.bypassMotion() }
                }
                InkLabel { visible: !Greetd.available; text: "Preview only: greetd is unavailable. No authentication is performed."; Layout.fillWidth: true }
                InkLabel { text: "If the graphical greeter fails, use the administrator-configured text-login/TTY recovery path. This optional component never replaces a display manager automatically."; variant: "small"; color: Theme.mutedInk; Layout.fillWidth: true }
                Item { Layout.fillHeight: true }
            }
        }
    }
    Rectangle { x: root.rollPosition - 10; y: (root.height - root.paperHeight) / 2 - 3; width: 20; height: root.paperHeight + 6; radius: 8; color: Theme.edge; border.color: Theme.accent }
}
