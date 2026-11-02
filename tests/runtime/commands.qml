import QtQuick
import Quickshell
import Quickshell.Io
import "services" as Services
ShellRoot {
    id: root
    property int step: 0
    function check(ok, message) {
        if (!ok) { console.error("FAIL: " + message); Qt.quit(); }
    }
    Services.CommandAction {
        id: action
        timeoutMs: 150
        onCompleted: {
            if (root.step === 0) {
                root.check(exitStatus === 7 && result.trim() === "out" && error.trim() === "err", "stdout/stderr/nonzero");
            } else if (root.step === 1) {
                root.check(exitStatus === 127 && error.indexOf("failed to start") >= 0, "missing executable");
            } else if (root.step === 2) {
                root.check(exitStatus === 124 && error.indexOf("timed out") >= 0, "timeout");
            } else {
                root.check(exitStatus === 0 && result.trim() === "recovered" && error === "", "recovery/reset");
                console.log("PASS: native command lifecycle"); Qt.quit(); return;
            }
            root.step++;
            next.start();
        }
    }
    Timer {
        id: next; interval: 100
        onTriggered: {
            if (root.step === 1) { action.timeoutMs = 3000; action.run(["/nonexistent/illuminated-test"]); }
            if (root.step === 2) { action.timeoutMs = 150; action.run(["sleep", "5"]); }
            if (root.step === 3) action.run(["printf", "recovered"]);
        }
    }
    Component.onCompleted: {
        check(!action.run([]) && action.error === "Empty command", "empty command");
        action.run(["sh", "-c", "printf out; printf err >&2; exit 7"]);
        check(!action.run(["true"]), "concurrent command rejected");
    }
}
