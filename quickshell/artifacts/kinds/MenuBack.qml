pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Services.UPower
import "../../services"
import "../../theme"
import "../../config"
import "../CardModel.js" as CardModel
import ".."
// Back of a session menu (Sleep): its entries, each acting or confirming inline.
Column {   // Sleep / Lock / Log Out, centred, no header
    id: menu
    required property var card
    required property var kind   // the SessionKind
    anchors.centerIn: parent
    width: parent.width - 2 * menu.card.pad
    spacing: 6 * menu.card.k
    Repeater {
        model: menu.kind.entries
        CardAction {
            id: entry
            required property string modelData
            width: menu.width; height: 30 * menu.card.k
            text: menu.kind.entryText(modelData)
            horizontalAlignment: Text.AlignHCenter
            ink: menu.card.backSurface.ink; faceWidth: menu.card.width; faceHeight: menu.card.height
            originX: menu.x + x; originY: menu.y + y; family: Theme.cardFamily; pixelSize: 22 * menu.card.k
            enabled: !SessionState.busy
            onTriggered: menu.kind.choose(entry.modelData)
        }
    }
    Text {   // a refused action (for example Sleep without a returning locker)
        visible: SessionState.error !== ""
        width: menu.width
        text: SessionState.error; textFormat: Text.PlainText
        wrapMode: Text.Wrap; horizontalAlignment: Text.AlignHCenter
        font.family: Settings.fontFamily; font.pixelSize: Settings.smallPixelSize
        color: menu.card.backSurface.ink
    }
}
