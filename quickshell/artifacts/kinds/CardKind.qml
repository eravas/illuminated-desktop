pragma ComponentBehavior: Bound
import QtQuick
import "../CardModel.js" as CardModel
// What a ServiceCard asks of its kind (kinds/Kinds.js names the adapterRoot). The card keeps
// flip, selection, gesture, face and chin; the kind binds them to its service. Only the
// card's own kind is instantiated, so a volume card binds no battery service.
Item {
    required property var card            // the ServiceCard
    visible: false
    property real level: 0                // 0..1; drawn as the card's live fill
    property real value: level            // where a drag starts from
    property bool present: true           // false: the art dims (no battery)
    property string detail: ""
    property var presentation: ({surface: CardModel.plain(card.colours), glyph: "", value: detail})
    property Component back: null         // null: the card has no back
    // A click: true when handled; otherwise the card turns over if it has a back.
    function activate() { return false; }
    function setLevel(value) {}
    function step(delta) {}               // a wheel notch: ±1
    function flipped(isFlipped) {}
    function deselected() {}
    function release() {}                 // the card is going away
}
