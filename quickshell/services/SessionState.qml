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
    // Sleep with the shell's own lock screen: waiting for the compositor to confirm the lock.
    property bool awaitingLock: false
    readonly property bool busy: command.busy || awaitingLock
    function select(action) {
        if (["lock", "logout", "suspend", "reboot", "poweroff"].indexOf(action) >= 0 && !busy) { pending = action; error = ""; expiry.restart(); }
    }
    function cancel() { pending = ""; expiry.stop(); }
    function confirm() {
        const action = pending;
        cancel();
        if (!action || busy) return false;
        // With the shell's lock screen loaded, lock in-process: Lock locks; Sleep suspends once the
        // compositor reports the lock secure (never on an unlocked session). Without a confirmed
        // lock within lock.timeout, the lock.fallback locker runs, and Sleep suspends only if it
        // succeeded: the rules of `illuminated lock`, without its polling processes.
        if ((action === "lock" || action === "suspend") && LockState.available) {
            if (action === "suspend") { suspending = true; awaitingLock = true; lockWait.restart(); }
            LockState.screen.lockNow();
            if (action === "suspend" && LockState.screen.secure) secured();
            return true;
        }
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
    function secured() {
        if (!awaitingLock) return;
        awaitingLock = false; lockWait.stop();
        suspending = false;
        command.timeoutMs = 15000;
        if (!command.run(Settings.powerCommands.suspend)) error = "No command configured for suspend";
    }
    Connections { target: LockState.screen; ignoreUnknownSignals: true; function onSecureChanged() { if (LockState.screen && LockState.screen.secure) root.secured(); } }
    Timer {
        id: lockWait
        interval: Settings.option("lock.timeout")
        onTriggered: {
            root.awaitingLock = false;
            if (LockState.screen) LockState.screen.abandon();   // only drops a lock never confirmed
            const fallback = Settings.option("lock.fallback") || [];
            if (!fallback.length) { root.suspending = false; root.error = "The lock screen did not confirm the lock; not suspending."; return; }
            command.timeoutMs = 15000;
            command.run(fallback);    // suspending stays set: suspend runs only if the fallback locked
        }
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
