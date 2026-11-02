import QtQuick
import Quickshell
import Quickshell.Io
import "config"
// Test entry for tests/runtime/single-config.py: the production shell plus a
// small IPC surface for reading resolved values and making Herbarium-style writes.
ShellRoot {
    Loader { source: "shell.qml" }
    IpcHandler {
        target: "configurationTest"
        function option(key: string): string { const value = Settings.option(key, null); return JSON.stringify(value === undefined ? null : value); }
        function update(key: string, value: string): string { return String(Settings.update(key, JSON.parse(value))); }
        function notice(): string { return Settings.notice; }
        function error(): string { return Settings.error; }
    }
}
