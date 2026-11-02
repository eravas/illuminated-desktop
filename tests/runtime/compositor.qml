import QtQuick
import Quickshell
import Quickshell.Io
import "compositors"
import "config"
ShellRoot {
    DesktopContext { id: desktop; shellScreen: Quickshell.screens[0] }
    IpcHandler {
        target: "test"
        function state(): string { return JSON.stringify({backend:DesktopState.backend, ready:DesktopState.ready, capabilities:DesktopState.capabilities, context:desktop.state}); }
        function activate(tag: int, extend: bool): void { const space=desktop.spaces.find(s => s.id === tag); if (space) desktop.activateWorkspace(space, extend); }
        function provider(name: string): void { Settings.compositor = name; }
    }
}
