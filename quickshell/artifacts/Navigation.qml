pragma Singleton
import QtQuick
import Quickshell
import "../config"
// Which hand or sheet is out, on which output, and where it was dealt from.
// A hand dealt sideways from the rail at height `lane`.
// device: a removable-media object handed over with its card (SURFACES.md §2a).
QtObject {
    signal launcherRequested()
    property string group: ""
    property string sheet: ""
    property var screen: null
    property real lane: 0
    property var trayItem: null
    property string device: ""
    property bool available: true
    function open(name, output, at) {
        if (!available) return;
        if (group === name && screen === output) { dismiss(); return; }
        screen = output || Quickshell.screens[0];
        const fallback = screen ? screen.height / 2 : 320;
        lane = at === undefined || at === null ? fallback : at;
        sheet = ""; device = ""; group = name;
    }
    function openDevice(id, output, at) {
        if (!available) return;
        if (device === id && screen === output) { dismiss(); return; }
        screen = output || Quickshell.screens[0];
        lane = at; sheet = ""; group = ""; device = id;
    }
    function expand(name) { sheet = name; }
    function dismiss() { sheet = ""; group = ""; device = ""; trayItem = null; }
}
