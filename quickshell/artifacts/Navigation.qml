pragma Singleton
import QtQuick
import Quickshell
import "../config"
// Which hand or sheet is out, on which output, and where it was dealt from.
// origin "left": a hand dealt sideways from the rail at height `lane` (v7).
// origin "top": a deck dealt down a vertical lane at x = `lane` (tests; the fallback with the rail off).
// device: a removable-media object handed over with its card (SURFACES.md §2a).
QtObject {
    signal launcherRequested()
    property string group: ""
    property string sheet: ""
    property var screen: null
    property real triggerX: 0
    property real lane: 0
    property string origin: "left"
    property var trayItem: null
    property string device: ""
    property bool available: true
    function open(name, output, at, from) {
        if (!available) return;
        if (group === name && screen === output) { dismiss(); return; }
        screen = output || Quickshell.screens[0];
        origin = from || (Settings.enableRail ? "left" : "top");
        const fallback = screen ? (origin === "top" ? screen.width / 2 : screen.height / 2) : 320;
        lane = at === undefined || at === null ? fallback : at;
        triggerX = origin === "top" ? lane : 0;
        sheet = ""; device = ""; group = name;
    }
    function openDevice(id, output, at) {
        if (!available) return;
        if (device === id && screen === output) { dismiss(); return; }
        screen = output || Quickshell.screens[0];
        origin = "left"; lane = at; sheet = ""; group = ""; device = id;
    }
    function expand(name) { sheet = name; }
    function dismiss() { sheet = ""; group = ""; device = ""; trayItem = null; }
}
