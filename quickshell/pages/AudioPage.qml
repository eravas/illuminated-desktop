pragma ComponentBehavior: Bound
import QtQuick
import "../theme"
import QtQuick.Controls
import QtQuick.Layouts
import "../components"
import "../services"
ColumnLayout {
    spacing: Theme.gap
    InkLabel { text: "Sound and microphones"; variant: "heading" }
    InkLabel { text: AudioState.available ? Math.round(AudioState.volume * 100) + "%" + (AudioState.muted ? " · muted" : "") : "PipeWire unavailable / no default output" }
    LevelSlider { Layout.fillWidth: true; from: 0; to: 1; value: AudioState.volume; enabled: AudioState.available; onMoved: AudioState.setVolume(value) }
    RowLayout {
        ActionButton { text: AudioState.muted ? "Unmute" : "Mute"; enabled: AudioState.available; onClicked: AudioState.toggleMute() }
        ActionButton { text: AudioState.micMuted ? "Enable microphone" : "Mute microphone"; enabled: AudioState.micAvailable; onClicked: AudioState.toggleMic() }
    }
    InkLabel { text: "Microphone gain" }
    LevelSlider { Layout.fillWidth: true; from: 0; to: 1; value: AudioState.micVolume; enabled: AudioState.micAvailable; onMoved: AudioState.setMicVolume(value) }
    InkLabel { text: "Outputs" }
    Repeater {
        model: AudioState.outputs
        ActionButton { required property var modelData; Layout.fillWidth: true; text: (modelData === AudioState.sink ? "✓ " : "") + (modelData.description || modelData.name); onClicked: AudioState.selectOutput(modelData) }
    }
    InkLabel { text: "Inputs" }
    Repeater {
        model: AudioState.inputs
        ActionButton { required property var modelData; Layout.fillWidth: true; text: (modelData === AudioState.source ? "✓ " : "") + (modelData.description || modelData.name); onClicked: AudioState.selectInput(modelData) }
    }
}
