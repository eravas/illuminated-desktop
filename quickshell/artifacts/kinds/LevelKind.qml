import QtQuick
import "../../services"
import "../CardModel.js" as CardModel
// Volume, Microphone, Brightness: a live fill you drag or scroll; a click mutes.
CardKind {
    id: adapter
    readonly property string name: card.kind
    // The service's own value (volume may exceed 1); the fill shows at most a full card.
    readonly property real value: name === "volume" ? AudioState.volume : name === "microphone" ? AudioState.micVolume : BrightnessState.value
    level: Math.min(1, value)
    presentation: name === "volume" ? CardModel.level("volume", {available: AudioState.available, level: level, muted: AudioState.muted}, card.colours)
        : name === "microphone" ? CardModel.level("microphone", {available: AudioState.micAvailable, level: level, muted: AudioState.micMuted}, card.colours)
        : CardModel.level("brightness", {available: BrightnessState.available, level: level}, card.colours)
    back: name === "volume" ? outputs : name === "microphone" ? card.genericBack : null
    Component { id: outputs; OutputsBack { card: adapter.card } }
    function activate() {
        if (name === "volume") AudioState.toggleMute();
        else if (name === "microphone") AudioState.toggleMic();
        return true;
    }
    function setLevel(value) {
        if (name === "volume") AudioState.setVolume(value);
        else if (name === "microphone") AudioState.setMicVolume(value);
        else BrightnessState.setValue(value);
    }
    function step(delta) { setLevel(value + delta * 0.05); }
    Component.onCompleted: if (name === "brightness") BrightnessState.read()
}
