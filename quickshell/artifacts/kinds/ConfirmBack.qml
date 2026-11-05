pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Services.UPower
import "../../services"
import "../../theme"
import "../../config"
import "../CardModel.js" as CardModel
import ".."
// Back of Shut Down / Reboot: Confirm?, a click confirms once armed.
Item {
    id: ask
    required property var card
    required property var kind   // the SessionKind
    objectName: "card-confirm"
    activeFocusOnTab: true
    readonly property bool failed: SessionState.error !== "" && !ask.kind.owned
    Accessible.role: Accessible.Button
    Accessible.name: "Confirm " + CardModel.sentence(ask.card.title).toLowerCase()
    Keys.onReturnPressed: function(event) { if (!event.isAutoRepeat) ask.kind.confirmFromBack(); }
    Keys.onSpacePressed: function(event) { if (!event.isAutoRepeat) ask.kind.confirmFromBack(); }
    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: ask.kind.confirmFromBack() }
    Column {
        id: prompt
        anchors.centerIn: parent
        width: parent.width - 2 * ask.card.pad
        spacing: 4 * ask.card.k
        visible: !ask.failed
        SplitText {
            width: prompt.width; height: 32 * ask.card.k
            text: "Confirm?"; horizontalAlignment: Text.AlignHCenter
            ink: ask.card.backSurface.ink; wash: ask.card.backTextWash; faceWidth: ask.card.width; faceHeight: ask.card.height
            originX: prompt.x + x; originY: prompt.y + y; family: Theme.cardFamily; pixelSize: 24 * ask.card.k
        }
        SplitText {
            width: prompt.width; height: 24 * ask.card.k
            text: CardModel.sentence(ask.card.title); horizontalAlignment: Text.AlignHCenter
            ink: ask.card.backSurface.ink; wash: ask.card.backTextWash; faceWidth: ask.card.width; faceHeight: ask.card.height
            originX: prompt.x + x; originY: prompt.y + y; family: Theme.cardFamily; pixelSize: 18 * ask.card.k
        }
    }
    Text {   // a refused command (for example Sleep without a returning locker)
        visible: ask.failed
        anchors.centerIn: parent
        width: parent.width - 2 * ask.card.pad
        text: SessionState.error; textFormat: Text.PlainText
        wrapMode: Text.Wrap; horizontalAlignment: Text.AlignHCenter
        font.family: Settings.fontFamily; font.pixelSize: Settings.smallPixelSize
        color: ask.card.backSurface.ink
    }
}
