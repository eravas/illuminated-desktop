import QtQuick
import Quickshell
import Quickshell.Io
import "tools" as Tools
ShellRoot {
    Tools.Launcher { id: launcher }
    IpcHandler {
        target: "test"
        function showLauncher(): void { launcher.toggle(); }
        function state(): string { return JSON.stringify({launcher: launcher.visible, matches: launcher.matches.length}); }
    }
}
