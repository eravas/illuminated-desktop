pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../config"
Singleton {
    id: root
    property real value: 0
    property bool available: false
    property string error: ""
    property real pendingValue: -1
    readonly property bool busy: command.busy
    // Internal path is injectable by the runtime fixture; config only selects a device.
    property string backlightRoot: "/sys/class/backlight"
    property string discoveredDevice: ""
    readonly property string device: Settings.backlightDevice || discoveredDevice
    property real actual: -1
    property real maximum: 0
    function update() {
        available = actual >= 0 && maximum > 0;
        if (available) { value = Math.max(0, Math.min(1, actual / maximum)); error = ""; }
        else error = "Backlight brightness files unavailable";
    }
    function discover() {
        discoveredDevice = "";
        if (!Settings.backlightDevice) { discovery.running = false; discovery.running = true; }
    }
    onBacklightRootChanged: Qt.callLater(discover)
    onDeviceChanged: { actual = -1; maximum = 0; available = false; Qt.callLater(read); }
    Component.onCompleted: discover()
    Connections { target: Settings; function onBacklightDeviceChanged() { root.discover(); } }
    function read() {
        if (!device) { available = false; error = "No backlight device found"; return; }
        currentFile.reload(); maximumFile.reload();
    }
    function setValue(level) {
        if (!available) return false;
        if (command.busy) { pendingValue = level; return true; }
        return command.run(["brightnessctl", "--class=backlight", "--device", device, "-m", "--min-value=1", "set", Math.round(Math.max(0.01, Math.min(1, level)) * 100) + "%"]);
    }
    // Discover once (or when configuration changes), never fork for polling reads.
    Process {
        id: discovery
        command: ["sh", "-c", "for device in \"$1\"/*; do [ -d \"$device\" ] && { printf '%s' \"${device##*/}\"; exit; }; done", "illuminated-backlight", root.backlightRoot]
        stdout: StdioCollector { onStreamFinished: { root.discoveredDevice = text.trim(); if (!root.discoveredDevice) root.read(); } }
    }
    FileView {
        id: currentFile
        path: root.device ? root.backlightRoot + "/" + root.device + "/actual_brightness" : ""
        printErrors: false
        onLoaded: { const n = Number(text().trim()); root.actual = Number.isFinite(n) ? n : -1; root.update(); }
        onLoadFailed: { root.actual = -1; root.update(); }
    }
    FileView {
        id: maximumFile
        path: root.device ? root.backlightRoot + "/" + root.device + "/max_brightness" : ""
        printErrors: false
        onLoaded: { const n = Number(text().trim()); root.maximum = Number.isFinite(n) ? n : 0; root.update(); }
        onLoadFailed: { root.maximum = 0; root.update(); }
    }
    CommandAction {
        id: command
        onCompleted: {
            if (exitStatus !== 0) root.error = error;
            if (exitStatus === 0) root.read();
            if (root.pendingValue >= 0) { const pending = root.pendingValue; root.pendingValue = -1; Qt.callLater(function() { root.setValue(pending); }); }
        }
    }
    Timer { interval: 3000; running: Settings.enableOsd; repeat: true; triggeredOnStart: true; onTriggered: root.read() }
}
