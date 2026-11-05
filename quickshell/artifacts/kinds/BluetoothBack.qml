pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Services.UPower
import "../../services"
import "../../theme"
import "../../config"
import "../CardModel.js" as CardModel
import ".."
// Back of Bluetooth: connected devices.
Item {
    id: bb
    required property var card
    readonly property var textFace: ({item: bb, ink: bb.card.backSurface.ink, wash: null})   // what text here is printed on
    SplitText {
        id: bbHeader
        face: bb.textFace
        x: bb.card.pad; y: bb.card.pad; width: bb.width - 2 * bb.card.pad; height: 30 * bb.card.k
        text: BluetoothState.failed ? bb.card.headerTitle + " · Failed" : bb.card.headerTitle
        pixelSize: 24 * bb.card.k
    }
    CardAction {
        id: devices
        face: bb.textFace
        x: bb.card.pad; y: bb.height - bb.card.pad - height; width: bb.width - 2 * bb.card.pad; height: 24 * bb.card.k
        text: "Devices ›"
        pixelSize: 18 * bb.card.k
        onTriggered: Navigation.expand(bb.card.spec.sheet || "bluetooth")
    }
    Column {
        id: bbList
        x: bb.card.pad; y: bbHeader.y + bbHeader.height + 4 * bb.card.k
        width: bb.width - 2 * bb.card.pad
        spacing: 2 * bb.card.k
        Repeater {
            model: BluetoothState.connectedDevices.slice(0, Math.max(0, Math.floor((devices.y - bbList.y) / (22 * bb.card.k))))
            Item {
                id: deviceRow
                required property var modelData
                width: bbList.width; height: 20 * bb.card.k
                Text {   // Bluetooth glyph in the left margin, slightly right of its centre
                    x: bb.card.geo.frame / 2 + 1.5 * bb.card.k - width / 2 - bbList.x
                    anchors.verticalCenter: parent.verticalCenter
                    text: "ᛒ"; textFormat: Text.PlainText
                    font.pixelSize: 11 * bb.card.k; color: bb.card.backSurface.ink
                }
                SplitText {
                    face: bb.textFace
                    anchors.fill: parent
                    text: deviceRow.modelData.name
                    pixelSize: 17 * bb.card.k
                }
            }
        }
    }
}
