pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Services.UPower
import "../../services"
import "../../theme"
import "../../config"
import "../CardModel.js" as CardModel
import ".."
// Back of Sound and Devices: the outputs, and the way to the mixer.
Item {
    id: ob
    required property var card
    // Landscape (Sound): Mixer in the right quarter, centred. Portrait (Devices):
    // a quarter column is too narrow for the word, so Mixer is a footer line.
    readonly property bool wide: ob.card.aspectRatio > 1
    readonly property real listWidth: wide ? ob.width * 0.75 - ob.card.pad : ob.width - 2 * ob.card.pad
    CardAction {   // first in focus order: the way out to the full mixer
        id: mixer
        x: ob.wide ? ob.width * 0.75 : ob.card.pad
        width: ob.wide ? ob.width * 0.25 - ob.card.geo.frame : ob.width - 2 * ob.card.pad
        height: implicitHeight
        y: ob.wide ? (ob.height - height) / 2 : ob.height - ob.card.pad - height
        text: "Mixer"; horizontalAlignment: ob.wide ? Text.AlignHCenter : Text.AlignLeft
        ink: ob.card.backSurface.ink; wash: ob.card.backTextWash; faceWidth: ob.card.width; faceHeight: ob.card.height
        originX: x; originY: y; family: Theme.cardFamily; pixelSize: 16 * ob.card.k
        onTriggered: Navigation.expand(ob.card.spec.sheet || "audio")
    }
    SplitText {
        id: obHeader
        x: ob.card.pad; y: ob.card.pad; width: ob.listWidth; height: 30 * ob.card.k
        text: "Output"; ink: ob.card.backSurface.ink; wash: ob.card.backTextWash
        faceWidth: ob.card.width; faceHeight: ob.card.height; originX: x; originY: y
        family: Theme.cardFamily; pixelSize: 24 * ob.card.k
    }
    Column {
        id: obList
        x: ob.card.pad; y: obHeader.y + obHeader.height + 4 * ob.card.k
        width: ob.listWidth
        spacing: 2 * ob.card.k
        Repeater {
            model: AudioState.outputs.slice(0, Math.max(0, Math.floor(((ob.wide ? ob.height - ob.card.pad : mixer.y) - obList.y) / (24 * ob.card.k))))
            CardAction {
                id: outputRow
                required property var modelData
                readonly property real level: AudioState.levelOf(modelData)
                width: obList.width; height: 22 * ob.card.k
                opacity: modelData === AudioState.sink ? 1 : 0.72
                text: (level >= 0 ? Math.round(level * 100) + "% " : "") + (modelData.description || modelData.nickname || modelData.name)
                ink: ob.card.backSurface.ink; wash: ob.card.backTextWash; faceWidth: ob.card.width; faceHeight: ob.card.height
                originX: obList.x + x; originY: obList.y + y; family: Theme.cardFamily; pixelSize: 18 * ob.card.k
                onTriggered: AudioState.selectOutput(outputRow.modelData)
            }
        }
    }
}
