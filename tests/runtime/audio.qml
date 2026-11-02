import QtQuick
import Quickshell
import "artifacts"
import Quickshell.Io
import "services"
ShellRoot {
    id: root
    CardsLayer { id: cards }
    Loader { source: "osd.qml" }
    Component.onCompleted: Navigation.open("sound", Quickshell.screens[0], 500, "top")
    function levelFill(node) { if (node.objectName === "service-level-fill") return {width:node.width,height:node.height}; for (const child of node.children || []) { const found=levelFill(child); if(found)return found; } return null; }
    IpcHandler {
        target: "test"
        function state(): string { return JSON.stringify({fill: cards.cardItems.count ? root.levelFill(cards.cardItems.itemAt(0).card) : null, card: cards.cardItems.count ? ({x: cards.cardItems.itemAt(0).x, y: cards.cardItems.itemAt(0).y, width: cards.cardItems.itemAt(0).width, height: cards.cardItems.itemAt(0).height}) : null, available: AudioState.available, volume: AudioState.volume, muted: AudioState.muted, micAvailable: AudioState.micAvailable, micMuted: AudioState.micMuted, micVolume: AudioState.micVolume, outputs: AudioState.outputs.map(n => ({id: n.id, name: n.name})), inputs: AudioState.inputs.map(n => ({id: n.id, name: n.name})), sink: AudioState.sink ? AudioState.sink.name : ""}); }
        function volume(value: real): void { AudioState.setVolume(value); }
        function mute(): void { AudioState.toggleMute(); }
        function micVolume(value: real): void { AudioState.setMicVolume(value); }
        function microphone(): void { AudioState.toggleMic(); }
        function output(index: int): void { AudioState.selectOutput(AudioState.outputs[index]); }
    }
}
