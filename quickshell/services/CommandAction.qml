import QtQuick
import Quickshell.Io
Item {
    id: root
    visible: false
    property bool busy: false
    property string result: ""
    property string error: ""
    property int exitStatus: -1
    property bool started: false
    property int timeoutMs: 15000   // 0 = no time limit (a locker that runs until unlock)
    signal completed()
    function finish(code, message) {
        if (!busy) return;
        deadline.stop(); startCheck.stop();
        exitStatus = code;
        if (message) error = message;
        busy = false;
        completed();
    }
    function run(argv) {
        if (busy || process.running) return false;
        result = ""; error = ""; exitStatus = -1; started = false;
        if (!argv || !argv.length) { error = "Empty command"; return false; }
        busy = true;
        process.command = argv;
        process.running = true;
        startCheck.start(); if (timeoutMs > 0) deadline.start();
        return true;
    }
    Timer {
        id: startCheck
        interval: 2000
        onTriggered: if (root.busy && !root.started) {
            if (process.running) process.signal(9);
            root.finish(127, "Process failed to start; check executable and permissions.");
        }
    }
    Timer {
        id: deadline
        interval: root.timeoutMs
        onTriggered: {
            process.signal(9);
            root.finish(124, "Command timed out. Verify system state before retrying.");
        }
    }
    Process {
        id: process
        stdout: StdioCollector { onStreamFinished: root.result = this.text }
        stderr: StdioCollector { onStreamFinished: if (this.text) root.error = this.text }
        onStarted: { root.started = true; startCheck.stop(); }
        onExited: function(code, status) { Qt.callLater(function() { root.finish(code, status ? "Process crashed" : ""); }); }
    }
}
