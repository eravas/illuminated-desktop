import QtQuick
import Quickshell
import Quickshell.Io
import "services"
import "config"
// Test entry: the shell's lock screen (lock.qml, as features.lock loads it) and the session
// actions, with harmless command substitutes.
ShellRoot {
    Loader { source: "lock.qml" }
    Component.onCompleted: {
        Settings.lockCommand = ["sh", "-c", "touch /project/artifacts/development/lock-substitute"];
        Settings.powerCommands = ({suspend: ["sh", "-c", "touch /project/artifacts/development/suspend-substitute"], reboot: ["true"], poweroff: ["true"]});
    }
    IpcHandler {
        target: "test"
        function sleep(): void { SessionState.select("suspend"); SessionState.confirm(); }
        function state(): string { return JSON.stringify({available: LockState.available, secure: LockState.available && LockState.screen.secure, busy: SessionState.busy, error: SessionState.error}); }
    }
}
