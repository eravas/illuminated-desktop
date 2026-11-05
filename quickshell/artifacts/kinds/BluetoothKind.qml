pragma ComponentBehavior: Bound
import QtQuick
import "../../services"
import "../CardModel.js" as CardModel
// Bluetooth: a click switches the radio; the back lists connected devices.
CardKind {
    id: adapterRoot
    readonly property var connected: BluetoothState.connectedDevices
    presentation: CardModel.bluetooth({available: BluetoothState.available, enabled: BluetoothState.enabled, connecting: BluetoothState.connecting,
                                       failed: BluetoothState.failed, connected: connected.length,
                                       name: connected.length ? connected[0].name : ""}, card.colours)
    back: Component { BluetoothBack { card: adapterRoot.card } }
    function activate() { BluetoothState.toggle(); return true; }
}
