pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Services.UPower
import "../../services"
import "../../theme"
import "../../config"
import "../CardModel.js" as CardModel
import ".."
// Back of Wi-Fi: the connected network, then the strongest others.
Item {
    id: nb
    required property var card
    readonly property var textFace: ({item: nb, ink: nb.card.backSurface.ink, wash: null})   // what text here is printed on
    SplitText {
        id: nbHeader
        face: nb.textFace
        x: nb.card.pad; y: nb.card.pad; width: nb.width - 2 * nb.card.pad; height: 30 * nb.card.k
        text: NetworkState.failed ? nb.card.headerTitle + " · Failed" : nb.card.headerTitle
        pixelSize: 24 * nb.card.k
    }
    CardAction {   // first in focus order
        id: seeAll
        face: nb.textFace
        x: nb.card.pad; y: nb.height - nb.card.pad - height; width: nb.width - 2 * nb.card.pad; height: 24 * nb.card.k
        text: "See All ›"
        pixelSize: 18 * nb.card.k
        onTriggered: Navigation.expand(nb.card.spec.sheet || "network")
    }
    Column {
        id: nbList
        x: nb.card.pad; y: nbHeader.y + nbHeader.height + 4 * nb.card.k
        width: nb.width - 2 * nb.card.pad
        spacing: 2 * nb.card.k
        Repeater {
            // The connected network, then the strongest others, as many as fit (at most 5).
            model: NetworkState.networks.slice(0, Math.max(0, Math.min(5, Math.floor((seeAll.y - nbList.y) / (22 * nb.card.k)))))
            CardAction {
                id: networkRow
                required property var modelData
                face: nb.textFace
                tabStop: false
                width: nbList.width; height: 20 * nb.card.k
                text: (modelData.connected ? "✓ " : "") + modelData.name
                pixelSize: 17 * nb.card.k
                onTriggered: if (!networkRow.modelData.connected) NetworkState.connectNetwork(networkRow.modelData, "")
            }
        }
    }
}
