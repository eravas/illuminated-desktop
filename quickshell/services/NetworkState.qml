pragma Singleton
import QtQuick
import QtQml
import Quickshell.Networking
import "../prompts"
QtObject {
    id: root
    readonly property bool available: Networking.backend !== NetworkBackendType.None
    readonly property bool enabled: Networking.wifiEnabled
    readonly property bool hardwareEnabled: Networking.wifiHardwareEnabled
    readonly property var devices: Networking.devices.values
    readonly property var wifiDevices: devices.filter(d => d.type === DeviceType.Wifi)
    readonly property var networks: wifiDevices.reduce((all, device) => all.concat(device.networks.values), [])
        .sort((a, b) => Number(b.connected) - Number(a.connected) || b.signalStrength - a.signalStrength)
    readonly property var connectedNetwork: networks.find(n => n.connected) || null
    readonly property bool wiredConnected: devices.some(d => d.type !== DeviceType.Wifi && d.connected)
    readonly property bool connecting: networks.some(n => n.stateChanging && !n.connected)
    // Signal strength (0..1) of the connected network; a wired link counts as full.
    readonly property real strength: connectedNetwork ? connectedNetwork.signalStrength : wiredConnected ? 1 : 0
    // Set by any network's connectionFailed; cleared by the next attempt or a connection.
    property bool failed: false
    onConnectedNetworkChanged: if (connectedNetwork) failed = false
    property Instantiator failures: Instantiator {
        model: root.networks
        delegate: Connections {
            required property var modelData
            target: modelData
            function onConnectionFailed(reason) { root.failed = true; root.error = ConnectionFailReason.toString(reason); }
        }
    }
    readonly property string summary: !available ? "Network unavailable" : devices.some(d => d.connected) ? "Connected" : "Disconnected"
    property int requestedRadio: -1
    property Timer radioCheck: Timer { interval: 6000; onTriggered: { if (root.requestedRadio >= 0 && root.enabled !== Boolean(root.requestedRadio)) root.error = "Wi-Fi change was not applied. Check authorization, rfkill and NetworkManager."; root.requestedRadio = -1; } }
    property string error: ""
    function toggle() { if (available && hardwareEnabled) { error = ""; failed = false; requestedRadio = Number(!enabled); Networking.wifiEnabled = !enabled; radioCheck.restart(); } }
    property bool scanningRequested: false
    onWifiDevicesChanged: if (scanningRequested) wifiDevices.forEach(d => d.scannerEnabled = true)
    function scan(active) { scanningRequested = active; wifiDevices.forEach(d => d.scannerEnabled = active); }
    // The passphrase goes through the prompt sheet; it is handed to NetworkManager and dropped.
    property var pending: null
    property PromptRequest passphrase: PromptRequest {
        kind: "wifi"; title: "Wi-Fi"; prompt: "Passphrase"; actionLabel: "Connect"
        onSubmitted: answer => { const n = root.pending; root.pending = null; Prompts.close(root.passphrase); if (n) root.connectNetwork(n, answer); }
        onCancelled: { root.pending = null; Prompts.close(root.passphrase); }
    }
    function askPassphrase(network) {
        if (!network) return;
        pending = network;
        passphrase.message = "“" + network.name + "” needs its passphrase. It is passed to NetworkManager, which decides whether to save it.";
        passphrase.error = "";
        Prompts.show(passphrase);
    }
    function connectNetwork(network, password) {
        if (networks.indexOf(network) < 0) return;
        error = ""; failed = false;
        if (password) network.connectWithPsk(password); else network.connect();
    }
}
