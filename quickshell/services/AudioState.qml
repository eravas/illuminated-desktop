pragma Singleton
import QtQuick
import Quickshell.Services.Pipewire
QtObject {
    id: root
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property var audio: sink ? sink.audio : null
    readonly property var microphone: source ? source.audio : null
    readonly property bool available: Pipewire.ready && audio !== null && sink.ready
    readonly property bool micAvailable: Pipewire.ready && microphone !== null && source.ready
    readonly property real volume: available ? audio.volume : 0
    readonly property bool muted: available && audio.muted
    readonly property real micVolume: micAvailable ? microphone.volume : 0
    readonly property bool micMuted: micAvailable && microphone.muted
    readonly property var outputs: Pipewire.nodes.values.filter(n => n.audio && n.isSink && !n.isStream)
    readonly property var inputs: Pipewire.nodes.values.filter(n => n.audio && !n.isSink && !n.isStream)
    property PwObjectTracker tracker: PwObjectTracker { objects: [root.sink, root.source].filter(n => n !== null) }
    // Binds every output so the Sound card's back can show each device's level.
    property PwObjectTracker outputTracker: PwObjectTracker { objects: root.outputs }
    function levelOf(node) { return node && node.ready && node.audio ? node.audio.volume : -1; }
    function setVolume(value) { if (available) audio.volume = Math.max(0, Math.min(1, value)); }
    function toggleMute() { if (available) audio.muted = !audio.muted; }
    function setMicVolume(value) { if (micAvailable) microphone.volume = Math.max(0, Math.min(1, value)); }
    function toggleMic() { if (micAvailable) microphone.muted = !microphone.muted; }
    function selectOutput(node) { if (outputs.indexOf(node) >= 0) Pipewire.preferredDefaultAudioSink = node; }
    function selectInput(node) { if (inputs.indexOf(node) >= 0) Pipewire.preferredDefaultAudioSource = node; }
}
