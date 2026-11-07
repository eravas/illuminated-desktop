import QtQuick
import Quickshell
import Quickshell.Io
import "compositors"
import "config"
import "rail"
ShellRoot {
    Dock { id: dock }
    QtObject { id: counter; objectName: "dock-delegate-counter"; property var created: ({}); property var spaces: ({}) }
    Connections {
        target: dock.windowItems
        function onItemAdded(index, item) {
            const next = Object.assign({}, counter.created), id = item.client.id;
            next[id] = (next[id] || 0) + 1; counter.created = next;
        }
    }
    PanelWindow {
        implicitWidth: 64; implicitHeight: 600; color: "transparent"
        RailWorkspaces { id: workspaceView; anchors.fill: parent; context: desktop }
    }
    Connections {
        target: workspaceView.workspaceItems
        function onItemAdded(index, item) {
            const next = Object.assign({}, counter.spaces), id = item.space.id;
            next[id] = (next[id] || 0) + 1; counter.spaces = next;
        }
    }
    DesktopContext { id: desktop; shellScreen: Quickshell.screens[0] }
    IpcHandler {
        target: "test"
        function state(): string { return JSON.stringify({backend:DesktopState.backend, ready:DesktopState.ready, capabilities:DesktopState.capabilities, context:desktop.state, windows:DesktopState.windows, created:counter.created, spacesCreated:counter.spaces, workspaceEntries:Array.from({length:workspaceView.workspaceItems.count}, (_, i) => workspaceView.workspaceItems.itemAt(i).space), dock:Array.from({length:dock.windowItems.count}, (_, i) => ({id:dock.windowItems.itemAt(i).client.id, title:dock.windowItems.itemAt(i).title}))}); }
        function activate(tag: int, extend: bool): void { const space=desktop.spaces.find(s => s.id === tag); if (space) desktop.activateWorkspace(space, extend); }
        function provider(name: string): void { Settings.compositor = name; }
    }
}
