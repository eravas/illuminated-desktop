pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import "theme"
import "config"
import "components"
import "materials"
import "compositors"
import "services"
// The lock screen (features.lock, off by default). ext-session-lock through WlSessionLock, PAM
// through PamContext. Rules, in order:
//  1. Only PamResult.Success unlocks. Failed, Error, MaxTries and every PAM or IPC error keep the
//     screen locked and start a new conversation.
//  2. Nothing else sets `locked` to false, except `abandon` before the compositor has confirmed
//     the lock (secure = false), so the fallback locker can take over (`illuminated lock`).
//  3. If the shell dies while locked, the compositor keeps the screen covered (solid colour).
//     Recover from a TTY with your fallback locker (docs/V7.md, Lock screen).
// The surfaces are opaque; nothing behind them is ever drawn.
Scope {
    id: root
    readonly property string user: Quickshell.env("USER") || ""
    property string message: ""
    property bool error: false
    property bool busy: false
    property int failures: 0
    property var primary: null       // the screen with the field (focused when locking)

    WlSessionLock {
        id: session
        locked: false
        onSecureChanged: if (session.secure) root.begin()
        // One surface per screen; created by the lock (an implicit Component in the same file,
        // so it can see root, pam and session).
        WlSessionLockSurface {
            id: surface
            color: Theme.paper
            readonly property bool isPrimary: !root.primary || surface.screen === root.primary
            Image {
                visible: Settings.option("features.wallpaper") && status === Image.Ready
                anchors.fill: parent
                source: !Settings.option("features.wallpaper") ? "" : Settings.wallpaperPath ? "file://" + Settings.wallpaperPath : Qt.resolvedUrl("assets/wallpaper.jpg")
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: Math.round(surface.width * (surface.screen ? surface.screen.devicePixelRatio : 1))
                asynchronous: true
                cache: false
            }
            Rectangle { anchors.fill: parent; color: Theme.paper; opacity: 0.35 }
            Vellum {
                id: sheet
                width: Math.min(420, surface.width - 48); height: column.implicitHeight + 56
                x: Math.round((surface.width - width) / 2); y: Math.round((surface.height - height) * 0.4)
                offX: x; offY: y; washed: false; solid: true
                ColumnLayout {
                    id: column
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 28 }
                    spacing: 8
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: Qt.formatDateTime(Time.now, Settings.option("clock.timeFormat")); textFormat: Text.PlainText
                        font.family: Theme.cardFamily; font.bold: Theme.cardBold; font.pixelSize: Math.round(64 * Theme.typeScale)
                        color: Theme.ink
                    }
                    InkLabel { Layout.alignment: Qt.AlignHCenter; text: Qt.formatDateTime(Time.now, "dddd d MMMM"); variant: "small" }
                    InkLabel { Layout.alignment: Qt.AlignHCenter; Layout.topMargin: 10; text: root.user; visible: surface.isPrimary }
                    SearchField {
                        id: field
                        visible: surface.isPrimary
                        Layout.fillWidth: true
                        echoMode: pam.responseVisible ? TextInput.Normal : TextInput.Password
                        placeholderText: pam.active && pam.responseRequired ? (pam.message.replace(/:\s*$/, "") || "Password") : root.busy ? "Checking…" : "Waiting…"
                        enabled: pam.active && pam.responseRequired && !root.busy
                        inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                        focus: surface.isPrimary
                        onAccepted: { const t = text; text = ""; root.respond(t); }
                        onEnabledChanged: if (enabled) forceActiveFocus()
                    }
                    InkLabel {
                        Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter
                        visible: surface.isPrimary && text !== ""
                        text: root.message; variant: "small"
                        color: root.error ? Theme.urgent : Theme.mutedInk
                    }
                }
            }
        }
    }
    PamContext {
        id: pam
        config: Settings.option("lock.pam")
        onPamMessage: { root.busy = false; if (!pam.responseRequired) { root.message = pam.message; root.error = pam.messageIsError; } }
        onCompleted: result => {
            root.busy = false;
            if (result === PamResult.Success) { root.failures = 0; root.message = ""; session.locked = false; return; }
            root.failures++;
            root.error = true;
            root.message = result === PamResult.MaxTries ? "Too many attempts. Wait, then try again."
                         : result === PamResult.Failed ? "That was not accepted." : "Authentication error; trying again.";
            restart.restart();
        }
        onError: e => { root.busy = false; root.error = true; root.message = "PAM error (" + PamError.toString(e) + "); trying again."; restart.restart(); }
    }
    // A new conversation after a failure; later after repeated ones (PAM's own delays still apply).
    Timer { id: restart; interval: Math.min(5000, 400 * Math.max(1, root.failures)); onTriggered: root.begin() }
    function begin() {
        if (!session.locked || pam.active) return;
        if (!pam.start()) { root.error = true; root.message = "Could not start PAM (" + Settings.option("lock.pam") + "); trying again."; restart.restart(); }
    }
    function respond(text) {
        if (!pam.active || !pam.responseRequired) return;
        busy = true; error = false; message = "";
        pam.respond(text);
    }
    function lockNow() {
        if (session.locked) return;
        primary = DesktopState.focusedScreen;
        failures = 0; message = ""; error = false;
        session.locked = true;
    }
    IpcHandler {
        target: "lock"
        function lock(): void { root.lockNow(); }
        function status(): string { return JSON.stringify({locked: session.locked, secure: session.secure, pam: pam.active}); }
        // Give up a lock the compositor never confirmed, so another locker can take the session.
        function abandon(): bool { if (session.locked && !session.secure) { session.locked = false; return true; } return false; }
    }
}
