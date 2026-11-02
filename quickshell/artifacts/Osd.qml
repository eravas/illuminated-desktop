pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../components"
import "../theme"
import "../services"
PanelWindow {
    id: root
    property bool showing: false
    property string label: ""
    property real level: 0
    property bool audioReady: false
    implicitWidth: 280; implicitHeight: 100
    anchors { bottom: true }
    margins.bottom: 60
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "illuminated-osd"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    color: "transparent"
    mask: Region {}
    visible: showing || sheet.progress > 0
    function show(name, value) { label = name; level = value; showing = true; timeout.restart(); }
    Connections {
        target: AudioState
        function onVolumeChanged() { if (root.audioReady && AudioState.available) root.show(AudioState.muted ? "Muted" : "Volume", AudioState.volume); root.audioReady = AudioState.available; }
        function onMutedChanged() { if (AudioState.available) root.show(AudioState.muted ? "Muted" : "Volume", AudioState.volume); }
        function onMicMutedChanged() { if (AudioState.micAvailable) root.show(AudioState.micMuted ? "Microphone muted" : "Microphone enabled", AudioState.micMuted ? 0 : 1); }
    }
    Connections { target: BrightnessState; function onValueChanged() { if (BrightnessState.available) root.show("Luminance", BrightnessState.value); } }
    Timer { id: timeout; interval: 1200; onTriggered: root.showing = false }
    VellumSheet {
        id: sheet
        anchors.fill: parent
        opened: root.showing
        content: Component {
            ColumnLayout {
                InkLabel { text: root.label + " · " + Math.round(root.level * 100) + "%" }
                Item {
                    Layout.fillWidth: true; Layout.preferredHeight: 6
                    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 1; color: Theme.ink; opacity: 0.3 }
                    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width * Math.max(0, Math.min(1, root.level)); height: 4; radius: 1; color: Theme.accent }
                }
            }
        }
    }
}
