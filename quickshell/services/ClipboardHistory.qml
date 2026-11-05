pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../config"
// Clipboard history from cliphist (its watcher, `wl-paste --watch cliphist store`, is the
// user's to run). The list is read when the sheet opens, not polled. Choosing an entry
// decodes it and hands it to wl-copy; image entries are listed but only
// text is restored. Entries never become process arguments: they go through stdin.
Singleton {
    id: root
    property var entries: []          // [{line, id, preview, binary}]
    property string error: ""
    property bool loading: lister.running
    function refresh() { if (Settings.option("features.clipboard") && !lister.running) { error = ""; lister.running = true; } }
    function choose(entry) {
        if (!entry || decoder.running) return;
        if (entry.binary) { error = "Images can’t be restored from here yet"; return; }
        decoder.line = entry.line; decoder.running = true;
    }
    function remove(entry) { if (entry && !deleter.running) { deleter.line = entry.line; deleter.running = true; } }
    function parse(text) {
        return text.split("\n").filter(l => l.length).slice(0, 200).map(function(line) {
            const tab = line.indexOf("\t"), preview = tab >= 0 ? line.slice(tab + 1) : line;
            return {line: line, id: tab >= 0 ? line.slice(0, tab) : "", preview: preview, binary: preview.indexOf("[[ binary data") === 0};
        });
    }
    Process {
        id: lister
        command: ["cliphist", "list"]
        stdout: StdioCollector { onStreamFinished: root.entries = root.parse(this.text) }
        stderr: StdioCollector { onStreamFinished: if (this.text) root.error = this.text.trim() }
        onExited: function(code) { if (code !== 0 && !root.error) root.error = code === 127 ? "cliphist is not installed" : "cliphist list failed (" + code + ")"; }
    }
    component Piped: Process {
        property string line: ""
        stdinEnabled: true
        onStarted: { write(line + "\n"); stdinEnabled = false; }   // closing stdin ends the input
        onRunningChanged: if (!running) stdinEnabled = true
    }
    Piped {
        id: decoder
        command: ["cliphist", "decode"]
        // wl-copy (wl-clipboard, which cliphist uses) owns the selection, so it survives the
        // sheet closing; Quickshell.clipboardText needs a focused shell window.
        stdout: StdioCollector { onStreamFinished: { copier.line = this.text; copier.running = true; } }
        onExited: function(code) { if (code !== 0) root.error = "cliphist decode failed (" + code + ")"; }
    }
    Process {
        id: copier
        property string line: ""
        command: ["wl-copy"]
        stdinEnabled: true
        onStarted: { write(line); stdinEnabled = false; }
        onRunningChanged: if (!running) stdinEnabled = true
        onExited: function(code) { if (code !== 0) root.error = code === 127 ? "wl-copy (wl-clipboard) is not installed" : "wl-copy failed (" + code + ")"; }
    }
    Piped {
        id: deleter
        command: ["cliphist", "delete"]
        onExited: root.refresh()
    }
}
