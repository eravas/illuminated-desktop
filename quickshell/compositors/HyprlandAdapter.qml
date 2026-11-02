import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../services/WorkspaceLogic.js" as WorkspaceLogic
import "WindowLogic.js" as WindowLogic
import "../config"
Scope {
    id: root
    readonly property string kind: "workspaces"
    readonly property bool ready: health.connected && Hyprland.monitors.values.length > 0
    // Fully known: a focused monitor with an active workspace. Until then the adapter
    // keeps asking Hyprland (see settle below) instead of waiting for the next event.
    readonly property bool settled: ready && !!Hyprland.focusedMonitor && !!Hyprland.focusedMonitor.activeWorkspace
    readonly property string error: !health.path ? "Hyprland event socket not found (is HYPRLAND_INSTANCE_SIGNATURE set?)"
        : !health.connected ? "Native Hyprland IPC is disconnected"
        : !ready ? "Connected to Hyprland; waiting for its monitor list" : ""
    readonly property string focusedOutput: ready && Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
    readonly property var outputs: ready ? Hyprland.monitors.values : []
    readonly property var logoutCommand: ["hyprctl", "dispatch", Hyprland.usingLua ? "hl.dsp.exit()" : "exit"]
    readonly property var capabilities: ({multipleVisible: false, toggleSelection: false, urgency: true, windowState: true, focusWindow: true, moveWindow: true})
    // ── Dock (DESIGN.md §6) ──────────────────────────────────────────────
    readonly property var windows: ready ? WindowLogic.hyprlandWindows(Hyprland.toplevels.values, Hyprland.activeToplevel ? Hyprland.activeToplevel.address : "", Settings.dockMinimizeWorkspace) : []
    // Keep native QObject identity in the dock model; presentation remains live.
    readonly property var windowObjects: ready ? Hyprland.toplevels.values.filter(t => WindowLogic.hyprlandWindows([t], "", Settings.dockMinimizeWorkspace).length > 0) : []
    function windowData(toplevel) {
        return WindowLogic.hyprlandWindows([toplevel], Hyprland.activeToplevel ? Hyprland.activeToplevel.address : "", Settings.dockMinimizeWorkspace)[0] || ({});
    }
    readonly property string currentWorkspace: ready && Hyprland.focusedMonitor && Hyprland.focusedMonitor.activeWorkspace ? String(Hyprland.focusedMonitor.activeWorkspace.name) : ""
    function send(kind, vars) {
        const request = WindowLogic.dispatchFor(kind, Hyprland.usingLua, Settings.dockDispatch, vars);
        if (request) Hyprland.dispatch(request);
        return request !== "";
    }
    // A visible window: focusing it switches to its workspace. A minimised one comes here first.
    function focusWindow(w) {
        if (!ready || !w) return;
        if (w.minimized && currentWorkspace) send("move", {address: w.id, workspace: currentWorkspace});
        send("focus", {address: w.id});
    }
    // Shift-click: bring a window to the current workspace without leaving it.
    function bringWindow(w) { if (ready && w && currentWorkspace) send("move", {address: w.id, workspace: currentWorkspace}); }
    function minimizeActive() {
        const a = Hyprland.activeToplevel ? Hyprland.activeToplevel.address : "";
        if (ready && a) send("move", {address: a, workspace: "special:" + Settings.dockMinimizeWorkspace});
    }
    function reconcile() { if (health.connected) { Hyprland.refreshMonitors(); Hyprland.refreshWorkspaces(); Hyprland.refreshToplevels(); } }
    function context(name, allOutputs) {
        const monitor = ready ? outputs.find(m => m.name === name) : null;
        const spaces = monitor ? WorkspaceLogic.ordinaryWorkspaces(Hyprland.workspaces.values, name, allOutputs).map(w => ({id: w.id, name: w.name, kind: "workspace", output: w.monitor ? w.monitor.name : name, active: w.active, focused: w.focused, urgent: w.urgent, toplevels: {values: w.toplevels.values}})) : [];
        // Until Hyprland's objects know the active workspace, use the one-shot hyprctl seed.
        const seeded = !root.settled && seed.workspace !== 0 && monitor && seed.monitor === monitor.name;
        const selection = spaces.filter(w => w.active || (seeded && w.id === seed.workspace)).map(w => w.id);
        return {ready: !!monitor, modelKind: kind, monitorName: monitor ? monitor.name : name, monitorFocused: monitor ? monitor.focused || seeded : false,
            spaces: spaces, selection: selection};
    }
    function activate(space, extend) {
        if (!ready) return;
        const native = Hyprland.workspaces.values.find(w => w.id === space.id && w.monitor && w.monitor.name === space.output);
        if (native) native.activate();
    }
    Socket {
        id: health
        path: Hyprland.eventSocketPath
        connected: path !== ""
        parser: SplitParser { onRead: {} }
        onConnectedChanged: if (connected) root.reconcile()
    }
    Timer { interval: 2000; running: true; repeat: true; onTriggered: if (!health.connected && health.path) health.connected = true }
    Timer { interval: 10000; running: true; repeat: true; onTriggered: root.reconcile() }
    // The first refresh on connect can land before Hyprland has reported monitors, and the
    // focused monitor/active workspace are otherwise only filled by the next event (an idle
    // desktop may send none). Ask every 250 ms until both are known, for at most 10 s;
    // the 10 s reconcile and events take over after that, so this never becomes polling.
    property int settleTries: 0
    Timer {
        interval: 250; repeat: true
        running: health.connected && !root.settled && root.settleTries < 40
        onTriggered: { root.settleTries++; root.reconcile(); }
    }
    // One-shot seed for the active workspace while the objects above are still empty:
    // `hyprctl -j activeworkspace` once, as soon as monitors exist but nothing is focused.
    QtObject { id: seed; property int workspace: 0; property string name: ""; property string monitor: "" }
    Process {
        id: seedQuery
        command: ["hyprctl", "-j", "activeworkspace"]
        running: root.ready && !root.settled && seed.workspace === 0
        stdout: StdioCollector {
            onStreamFinished: {
                try { const w = JSON.parse(text); seed.monitor = w.monitor || ""; seed.name = String(w.name || w.id); seed.workspace = w.id || 0; }
                catch (e) { seed.workspace = -1; }   // unparsable: don't ask again
            }
        }
    }
}
