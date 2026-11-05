pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../config"
// Backlight level. brightnessctl does every write (it holds the permissions) and the first
// read, which names the device and reports a missing one. After that the level is read from
// sysfs on the 3 s timer: two small file reads instead of a fork and exec. A device whose
// sysfs files do not read falls back to brightnessctl.
Singleton {
    id: root
    property real value: 0
    property bool available: false
    property string error: ""
    property real pendingValue: -1
    property bool writing: false
    property string device: ""          // from brightnessctl's first field
    readonly property bool busy: command.busy
    readonly property string sysfs: (Quickshell.env("ILLUMINATED_BACKLIGHT_ROOT") || "/sys/class/backlight") + "/" + device
    function commandArguments() { return ["brightnessctl", "--class=backlight"].concat(Settings.backlightDevice ? ["--device", Settings.backlightDevice] : []); }
    function readSysfs() {
        if (!device || writing) return false;
        actual.reload(); maximum.reload();
        const level = parseInt(actual.text()), top = parseInt(maximum.text());
        if (!(top > 0) || isNaN(level)) return false;
        value = Math.max(0, Math.min(1, level / top)); available = true;
        return true;
    }
    function read() { if (readSysfs()) return; if (!command.busy) { writing = false; command.run(commandArguments().concat(["-m"])); } }
    function setValue(level) {
        if (!available) return false;
        if (command.busy) { pendingValue = level; return true; }
        writing = true;
        return command.run(commandArguments().concat(["-m", "--min-value=1", "set", Math.round(Math.max(0.01, Math.min(1, level)) * 100) + "%"]));
    }
    FileView { id: actual; path: root.device ? root.sysfs + "/actual_brightness" : ""; blockLoading: true; printErrors: false }
    FileView { id: maximum; path: root.device ? root.sysfs + "/max_brightness" : ""; blockLoading: true; printErrors: false }
    CommandAction {
        id: command
        onCompleted: {
            root.error = error;
            if (exitStatus === 0) {
                const match = result.match(/^([^,\n]+),[^,]*,\d+,(\d+)%/m);
                if (match) { root.device = match[1]; root.value = Number(match[2]) / 100; root.available = true; }
                if (root.pendingValue >= 0) { const pending = root.pendingValue; root.pendingValue = -1; Qt.callLater(function() { root.setValue(pending); }); }
                else root.writing = false;
            } else { if (!root.writing) root.available = false; root.writing = false; }
        }
    }
    Timer { interval: 3000; running: Settings.enableOsd; repeat: true; triggeredOnStart: true; onTriggered: root.read() }
}
