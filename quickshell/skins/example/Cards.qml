import QtQuick
import qs.skin
// A card of this skin's (an inkwell showing the volume; its cork deals Levels) and the Desk hand
// the seal deals: the inkwell and the built-in Sound card.
SkinCards {
    SkinCardSpec {
        name: "inkwell"
        title: "Ink"
        value: Math.round(ShellState.volume * 100) + "%"
        face: Component { InkwellFace {} }
    }
    SkinHand { name: "desk"; label: "Desk"; cards: ["skin:inkwell", "volume"] }
}
