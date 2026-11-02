pragma Singleton
import QtQuick
import Quickshell
import "../config"
import "../compositors"
Singleton {
    id: root
    property string pending: ""
    property bool suspending: false
    property string error: ""
    readonly property bool busy: command.busy
    function select(action) {
        if (["lock", "logout", "suspend", "reboot", "poweroff"].indexOf(action) >= 0 && !busy) { pending = action; error = ""; expiry.restart(); }
    }
    function cancel() { pending = ""; expiry.stop(); }
    function confirm() {
        const action = pending;
        cancel();
        if (!action || busy) return false;
        if (action === "suspend" && !Settings.lockReturnsWhenReady) {
            error = "Sleep needs a locker that returns once the screen is locked; the configured one keeps running until unlock. See commands.lockReturnsWhenReady.";
            return false;
        }
        // A locker that runs until unlock must never be killed by the command time limit.
        command.timeoutMs = action === "lock" && !Settings.lockReturnsWhenReady ? 0 : 15000;
        let argv;
        if (action === "lock") argv = Settings.lockCommand;
        else if (action === "logout") argv = Settings.logoutCommand.length ? Settings.logoutCommand : DesktopState.logoutCommand;
        else if (action === "suspend") { suspending = true; argv = Settings.lockCommand; }
        else argv = Settings.powerCommands[action];
        if (!argv || !argv.length) { error = "No command configured for " + action; suspending = false; return false; }
        return command.run(argv);
    }
    // An untouched confirmation cancels; the confirm card flips back with it.
    Timer { id: expiry; interval: Settings.confirmTimeout; onTriggered: root.cancel() }
    CommandAction {
        id: command
        onCompleted: {
            root.error = error || (exitStatus > 0 ? "Action refused: " + exitStatus : "");
            if (root.suspending) { root.suspending = false; if (exitStatus === 0) Qt.callLater(function() { command.run(Settings.powerCommands.suspend); }); }
        }
    }
}
