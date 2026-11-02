pragma Singleton
import QtQuick
import Quickshell
import "../config"
Singleton {
    id: root
    property real value: 0
    property bool available: false
    property string error: ""
    property real pendingValue: -1
    property bool writing: false
    readonly property bool busy: command.busy
    function commandArguments() { return ["brightnessctl", "--class=backlight"].concat(Settings.backlightDevice ? ["--device", Settings.backlightDevice] : []); }
    function read() { if (!command.busy) { writing = false; command.run(commandArguments().concat(["-m"])); } }
    function setValue(level) {
        if (!available) return false;
        if (command.busy) { pendingValue = level; return true; }
        writing = true;
        return command.run(commandArguments().concat(["-m", "--min-value=1", "set", Math.round(Math.max(0.01, Math.min(1, level)) * 100) + "%"]));
    }
    CommandAction {
        id: command
        onCompleted: {
            root.error = error;
            if (exitStatus === 0) {
                const match = result.match(/,(\d+)%/);
                if (match) { root.value = Number(match[1]) / 100; root.available = true; }
                if (root.pendingValue >= 0) { const pending = root.pendingValue; root.pendingValue = -1; Qt.callLater(function() { root.setValue(pending); }); }
                else if (root.writing) Qt.callLater(root.read);
            } else if (!root.writing) root.available = false;
        }
    }
    Timer { interval: 3000; running: Settings.enableOsd; repeat: true; triggeredOnStart: true; onTriggered: root.read() }
}
