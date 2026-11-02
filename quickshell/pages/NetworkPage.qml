pragma ComponentBehavior: Bound
import QtQuick
import "../theme"
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Networking
import "../components"
import "../services"
ColumnLayout {
    id: root
    property var selected: null
    spacing: Theme.gap
    Component.onCompleted: NetworkState.scan(true)
    Component.onDestruction: NetworkState.scan(false)
    InkLabel { text: "Connections"; variant: "heading" }
    InkLabel { text: NetworkState.summary + (NetworkState.hardwareEnabled ? "" : " · wireless hardware blocked/unavailable") }
    ActionButton { text: NetworkState.enabled ? "Disable Wi-Fi" : "Enable Wi-Fi"; enabled: NetworkState.available && NetworkState.hardwareEnabled; onClicked: NetworkState.toggle() }
    InkLabel { text: NetworkState.error; visible: text !== ""; Layout.fillWidth: true }
    Repeater {
        model: NetworkState.devices
        InkLabel { required property var modelData; text: modelData.name + " · " + (modelData.connected ? "connected" : "disconnected"); Layout.fillWidth: true }
    }
    Repeater {
        model: NetworkState.networks
        ColumnLayout {
            id: row
            required property var modelData
            Layout.fillWidth: true
            Connections { target: row.modelData; function onConnectionFailed(reason) { NetworkState.error = ConnectionFailReason.toString(reason); } }
            ActionButton {
                Layout.fillWidth: true
                text: row.modelData.name + " · " + Math.round(row.modelData.signalStrength * 100) + "% · " + ConnectionState.toString(row.modelData.state)
                onClicked: root.selected = row.modelData
            }
            RowLayout {
                visible: root.selected === row.modelData
                ActionButton { text: row.modelData.connected ? "Disconnect" : "Connect saved/open"; enabled: !row.modelData.stateChanging; onClicked: { if (row.modelData.connected) row.modelData.disconnect(); else NetworkState.connectNetwork(row.modelData, ""); } }
            }
        }
    }
    ActionButton { text: "Connect with passphrase…"; visible: root.selected !== null && !root.selected.connected; onClicked: NetworkState.askPassphrase(root.selected) }
    InkLabel { text: "Enterprise/VPN profiles and captive portals use your existing network tools. Authorization goes to your session's polkit agent (this shell's, with features.polkit)."; Layout.fillWidth: true }
}
