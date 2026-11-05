import QtQuick
import Quickshell
import Quickshell.Io
import "compositors"
import "config"
import "rail"
import "skin"
ShellRoot {
    id: root
    DesktopContext { id: desktop; shellScreen: Quickshell.screens[0] }
    Dock { id: dock; screen: Quickshell.screens[0] }
    FloatingWindow { id: railWindow; implicitWidth: 64; implicitHeight: 400; RailWorkspaces { anchors.fill: parent; context: desktop } }
    property var remembered: []
    property var rememberedSpaces: []
    function spaces() { return entries(railWindow.contentItem, "rail-space"); }
    function entries(node, name) { const wanted = name || "dock-entry"; let out = node.objectName === wanted ? [node] : []; for (const child of node.children || []) out = out.concat(entries(child, wanted)); return out; }
    IpcHandler {
        target: "test"
        function state(): string { return JSON.stringify({backend:DesktopState.backend, ready:DesktopState.ready, capabilities:DesktopState.capabilities, context:desktop.state}); }
        function activate(tag: int, extend: bool): void { const space=desktop.spaces.find(s => s.id === tag); if (space) desktop.activateWorkspace(space, extend); }
        function provider(name: string): void { Settings.compositor = name; }
        // Dock delegates: their titles, and how many are the same objects as when remembered.
        function dock(): string { const now = root.entries(dock.contentItem); return JSON.stringify({titles: now.map(e => e.title).sort(), kept: now.filter(e => root.remembered.indexOf(e) >= 0).length}); }
        function remember(): void { root.remembered = root.entries(dock.contentItem); root.rememberedSpaces = root.spaces(); }
        function railSpaces(): string { const now = root.spaces(); return JSON.stringify({count: now.length, kept: now.filter(e => root.rememberedSpaces.indexOf(e) >= 0).length}); }
    }
}
