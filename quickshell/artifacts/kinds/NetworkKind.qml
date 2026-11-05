pragma ComponentBehavior: Bound
import QtQuick
import "../../services"
import "../CardModel.js" as CardModel
// Wi-Fi: a click switches the radio; the back lists networks and scans while it is up.
CardKind {
    id: adapterRoot
    presentation: CardModel.network({enabled: NetworkState.enabled, connecting: NetworkState.connecting, failed: NetworkState.failed,
                                     connected: NetworkState.connectedNetwork !== null || NetworkState.wiredConnected,
                                     stage: CardModel.signalStage(NetworkState.strength),
                                     name: NetworkState.connectedNetwork ? NetworkState.connectedNetwork.name : NetworkState.wiredConnected ? "Wired" : ""}, card.colours)
    back: Component { NetworkBack { card: adapterRoot.card } }
    function activate() { NetworkState.toggle(); return true; }
    function flipped(isFlipped) { NetworkState.scan(isFlipped); }
    function release() { if (card.flipped) NetworkState.scan(false); }
}
