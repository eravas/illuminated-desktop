pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Services.UPower
import "../../services"
import "../../theme"
import "../../config"
import "../CardModel.js" as CardModel
import ".."
// The default back: the card's title and value, and its sheet when it has one.
Item {
    id: gb
    required property var card
    readonly property var textFace: ({item: gb, ink: gb.card.backSurface.ink, wash: gb.card.backTextWash})   // what text here is printed on
    SplitText {
        id: gbHeader
        face: gb.textFace
        x: gb.card.pad; y: gb.card.pad; width: gb.width - 2 * gb.card.pad; height: 30 * gb.card.k
        text: gb.card.headerTitle
        pixelSize: 24 * gb.card.k
    }
    SplitText {
        face: gb.textFace
        x: gb.card.pad; y: gbHeader.y + gbHeader.height; width: gb.width - 2 * gb.card.pad; height: 24 * gb.card.k
        text: gb.card.presentation.value
        pixelSize: 18 * gb.card.k
    }
    CardAction {
        face: gb.textFace
        visible: gb.card.spec.sheet !== ""
        x: gb.card.pad; y: gb.height - gb.card.pad - height; width: gb.width - 2 * gb.card.pad; height: 24 * gb.card.k
        text: "Open ›"
        pixelSize: 18 * gb.card.k
        onTriggered: Navigation.expand(gb.card.spec.sheet)
    }
}
