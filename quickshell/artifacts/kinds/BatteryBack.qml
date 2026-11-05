pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Services.UPower
import "../../services"
import "../../theme"
import "../../config"
import "../CardModel.js" as CardModel
import ".."
// Back of Battery ("Charge"): status, profile, time remaining, charge limit.
Item {
    id: cb
    required property var card
    readonly property var textFace: ({item: cb, ink: cb.card.backSurface.ink, wash: cb.card.backTextWash})   // what text here is printed on
    required property var kind   // the BatteryKind: its details
    readonly property bool held: cb.kind.externalPower && !cb.kind.batteryFull
    SplitText {
        id: cbHeader
        face: cb.textFace
        x: cb.card.pad; y: cb.card.pad; width: cb.width - 2 * cb.card.pad; height: 30 * cb.card.k
        text: cb.card.headerTitle
        pixelSize: 24 * cb.card.k
    }
    Column {
        id: stats
        x: cb.card.pad; y: cbHeader.y + cbHeader.height + 2 * cb.card.k
        width: cb.width - 2 * cb.card.pad
        spacing: 3 * cb.card.k
        Repeater {
            model: [
                {label: "Status", value: cb.card.percentText + "% • held", shown: cb.held},
                {label: "Profile", value: cb.kind.profileText, shown: true},
                {label: "Remaining", value: cb.kind.remainingText, shown: cb.kind.remainingText !== "—"},
                {label: "Limit", value: cb.kind.chargeLimit, shown: cb.kind.chargeLimit !== ""}
            ].filter(row => row.shown)
            Column {
                id: stat
                required property var modelData
                width: stats.width
                SplitText {
                    face: cb.textFace
                    width: stat.width; height: 17 * cb.card.k
                    text: stat.modelData.label; bold: false
                    pixelSize: 15 * cb.card.k
                }
                SplitText {
                    face: cb.textFace
                    width: stat.width; height: 25 * cb.card.k
                    text: stat.modelData.value
                    pixelSize: 22 * cb.card.k
                }
            }
        }
    }
}
