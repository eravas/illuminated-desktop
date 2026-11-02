pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import "MangoLogic.js" as Logic
import "WindowLogic.js" as WindowLogic
import "../services"
Scope {
    id: root
    readonly property string kind: "tags"
    property var monitors: []
    property var tags: []
    property var clients: []
    property var seen: ({monitors:false, tags:false, clients:false})
    property string error: ""
    readonly property bool ready: seen.monitors && seen.tags && seen.clients && monitorWatch.running && tagWatch.running && clientWatch.running
    readonly property string focusedOutput: ready ? (monitors.find(m => m.active) || {}).name || "" : ""
    readonly property var outputs: ready ? monitors : []
    readonly property var logoutCommand: ["mmsg", "dispatch", "quit"]
    readonly property var capabilities: ({multipleVisible:true, toggleSelection:true, urgency:true, windowState:true, focusWindow:false, moveWindow:false})
    // Dock: Mango's IPC has no documented focus-by-id, so a click views the window's first tag.
    readonly property var windows: ready ? WindowLogic.mangoWindows(clients) : []
    function focusWindow(w) {
        if (!w || !w.workspace) return;
        const client = clients.find(c => String(c.id) === w.id);
        if (client) activate({id: w.workspace, output: client.monitor}, false);
    }
    function bringWindow(w) {}
    function minimizeActive() {}
    function mark(channel, value) { const state = Object.assign({}, seen); state[channel] = value; seen = state; }
    function accept(channel, text) {
        try {
            const data = JSON.parse(text);
            if (data.error) throw Error(data.error);
            const value = data[channel === "tags" ? "all_tags" : channel];
            if (!Array.isArray(value)) throw Error("Unexpected Mango IPC schema: " + channel);
            if (channel === "monitors") monitors = value;
            else if (channel === "tags") tags = value;
            else clients = value;
            mark(channel, true); error = "";
        } catch (e) { mark(channel, false); error = String(e); }
    }
    function context(name, allOutputs) {
        const state = Logic.context(monitors, tags, clients, name, allOutputs, ready);
        delete state.title; // The former bar was the only title consumer.
        return state;
    }
    function activate(space, extend) {
        if (!ready || !/^[A-Za-z0-9_.:-]+$/.test(space.output)) return;
        const monitor = monitors.find(m => m.name === space.output);
        if (!monitor || !(tags.find(g => g.monitor === space.output) || {tags:[]}).tags.some(t => t.index === space.id)) return;
        const selected = Logic.selection((monitor.active_tags || []).filter(t => t > 0), space.id, extend);
        if (selected.length) action.run(["mmsg", "dispatch", "viewcrossmon," + selected.join("|") + "," + space.output]);
    }
    CommandAction { id: action; onCompleted: if (exitStatus !== 0) root.error = error || "Mango dispatch failed" }
    component Stream: Process {
        id: stream
        required property string channel
        required property string request
        command: ["mmsg", "watch", request]
        running: true
        stdout: SplitParser { onRead: function(data) { root.accept(stream.channel, data); } }
        stderr: StdioCollector { onStreamFinished: if (text) root.error = text }
        onExited: root.mark(channel, false)
    }
    Stream { id: monitorWatch; channel: "monitors"; request: "all-monitors" }
    Stream { id: tagWatch; channel: "tags"; request: "all-tags" }
    Stream { id: clientWatch; channel: "clients"; request: "all-clients" }
    component Snapshot: Process {
        id: query
        required property string channel
        required property string request
        command: ["mmsg", "get", request]
        stdout: StdioCollector { onStreamFinished: root.accept(query.channel, text) }
        onExited: function(code) { if (code !== 0) root.mark(channel, false); }
    }
    Snapshot { id: monitorQuery; channel: "monitors"; request: "all-monitors" }
    Snapshot { id: tagQuery; channel: "tags"; request: "all-tags" }
    Snapshot { id: clientQuery; channel: "clients"; request: "all-clients" }
    function reconcile() { [monitorQuery, tagQuery, clientQuery].forEach(p => { if (!p.running) p.running = true; }); }
    Timer {
        interval: 2000; running: true; repeat: true
        onTriggered: {
            [monitorWatch, tagWatch, clientWatch].forEach(p => { if (!p.running) { root.mark(p.channel, false); p.running = true; } });
        }
    }
    Timer { interval: 10000; running: true; repeat: true; onTriggered: root.reconcile() }
}
