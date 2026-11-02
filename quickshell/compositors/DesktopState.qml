pragma Singleton
import QtQuick
import Quickshell
import "../config"
Singleton {
    id: root
    function detect() {
        if (Settings.compositor !== "auto") return Settings.compositor;
        const desktop = (Quickshell.env("XDG_CURRENT_DESKTOP") || "").toLowerCase();
        if (desktop.indexOf("mango") >= 0) return "mango";
        if (desktop.indexOf("hyprland") >= 0) return "hyprland";
        return Quickshell.env("MANGO_INSTANCE_SIGNATURE") && !Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") ? "mango" : Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") ? "hyprland" : "none";
    }
    readonly property string backend: detect()
    readonly property var adapter: backendLoader.item
    readonly property string error: adapter ? adapter.error || "" : backend === "none" ? "" : "Unsupported compositor adapter"
    readonly property bool ready: adapter ? adapter.ready : false
    readonly property string kind: adapter ? adapter.kind : "workspaces"
    readonly property string focusedOutput: adapter ? adapter.focusedOutput : ""
    readonly property var outputs: adapter ? adapter.outputs : []
    readonly property var logoutCommand: adapter ? adapter.logoutCommand : []
    readonly property var capabilities: adapter ? adapter.capabilities : ({multipleVisible:false, toggleSelection:false, urgency:false, windowState:false})
    readonly property var focusedScreen: Quickshell.screens.find(s => s.name === focusedOutput) || Quickshell.screens[0] || null
    function context(name, allOutputs) { return adapter ? adapter.context(name, allOutputs) : ({ready:false, modelKind:kind, monitorName:name, monitorFocused:false, spaces:[], selection:[], title:"Waiting for a supported compositor"}); }
    readonly property var windows: adapter && adapter.windows ? adapter.windows : []
    function focusWindow(w) { if (adapter && ready && adapter.focusWindow) adapter.focusWindow(w); }
    function bringWindow(w) { if (adapter && ready && capabilities.moveWindow) adapter.bringWindow(w); }
    function minimizeActive() { if (adapter && ready && adapter.minimizeActive) adapter.minimizeActive(); }
    function activate(space, extend) { if (adapter && ready && ((kind === "tags" && space.kind === "tag") || (kind === "workspaces" && space.kind === "workspace"))) adapter.activate(space, extend); }
    Loader { id: backendLoader; active: Settings.ready; source: ({hyprland:"HyprlandAdapter.qml", mango:"MangoAdapter.qml"})[root.backend] || "" }
}
