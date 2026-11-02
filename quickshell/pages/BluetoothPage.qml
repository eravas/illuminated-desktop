pragma ComponentBehavior: Bound
import QtQuick
import "../theme"
import QtQuick.Layouts
import Quickshell.Bluetooth
import "../components"
import "../services"
ColumnLayout {
    spacing: Theme.gap
    Component.onDestruction: BluetoothState.scan(false)
    InkLabel { text: "Bluetooth devices"; variant: "heading" }
    InkLabel { text: BluetoothState.available ? BluetoothState.adapter.name + " · " + BluetoothAdapterState.toString(BluetoothState.adapter.state) : "No Bluetooth adapter / BlueZ unavailable" }
    Flow {
        Layout.fillWidth: true
        spacing: Theme.gap
        ActionButton { text: BluetoothState.enabled ? "Power off" : "Power on"; enabled: BluetoothState.available; onClicked: BluetoothState.toggle() }
        ActionButton { text: BluetoothState.available && BluetoothState.adapter.discovering ? "Stop scan" : "Scan"; enabled: BluetoothState.enabled; onClicked: BluetoothState.scan(!BluetoothState.adapter.discovering) }
    }
    InkLabel { text: BluetoothState.error; visible: text !== ""; Layout.fillWidth: true }
    Repeater {
        model: BluetoothState.devices
        ColumnLayout {
            id: row
            required property var modelData
            property bool confirmForget: false
            InkLabel { text: row.modelData.name + " · " + BluetoothDeviceState.toString(row.modelData.state) + (row.modelData.batteryAvailable ? " · " + Math.round(row.modelData.battery * 100) + "%" : ""); Layout.fillWidth: true }
            Flow {
        Layout.fillWidth: true
        spacing: Theme.gap
                ActionButton { text: row.modelData.connected ? "Disconnect" : row.modelData.paired ? "Connect" : "Pair"; enabled: !row.modelData.pairing; onClicked: BluetoothState.connectDevice(row.modelData) }
                ActionButton { text: row.modelData.trusted ? "Untrust" : "Trust"; enabled: row.modelData.paired; onClicked: row.modelData.trusted = !row.modelData.trusted }
                ActionButton { text: row.confirmForget ? "Confirm forget" : "Forget"; visible: row.modelData.paired; onClicked: { if (row.confirmForget) row.modelData.forget(); else row.confirmForget = true; } }
                ActionButton { text: "Cancel pairing"; visible: row.modelData.pairing; onClicked: row.modelData.cancelPair() }
            }
        }
    }
    InkLabel { text: "Pairing requiring a PIN/passkey needs your existing BlueZ authentication agent. Device state is shown above; this shell does not replace that agent."; Layout.fillWidth: true }
}
