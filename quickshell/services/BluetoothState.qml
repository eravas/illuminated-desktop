pragma Singleton
import QtQuick
import Quickshell.Bluetooth
QtObject {
    id: root
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var adapters: Bluetooth.adapters.values
    readonly property var devices: adapter ? adapter.devices.values : []
    readonly property bool available: adapter !== null
    readonly property bool enabled: available && adapter.enabled
    readonly property var connectedDevices: devices.filter(d => d.connected)
    readonly property bool connecting: devices.some(d => d.pairing || d.state === BluetoothDeviceState.Connecting)
    // A failed power change or device action (see verify below) until the next action.
    readonly property bool failed: error !== ""
    property var pendingDevice: null
    property string expectation: ""
    property int requestedRadio: -1
    property Timer verify: Timer {
        interval: 8000
        onTriggered: {
            if (root.requestedRadio >= 0 && root.enabled !== Boolean(root.requestedRadio)) root.error = "Bluetooth power change was not applied. Check rfkill, BlueZ and authorization.";
            if (root.expectation && (!root.pendingDevice || (root.expectation === "paired" ? !root.pendingDevice.paired : root.pendingDevice.connected !== (root.expectation === "connected")))) root.error = "Bluetooth action did not complete. Check the authentication agent and device state.";
            root.expectation = ""; root.pendingDevice = null; root.requestedRadio = -1;
        }
    }
    property string error: ""
    function toggle() { if (available) { error = ""; requestedRadio = Number(!enabled); adapter.enabled = !enabled; verify.restart(); } }
    property bool scanningRequested: false
    onAdapterChanged: if (scanningRequested && available && enabled) adapter.discovering = true
    onEnabledChanged: if (scanningRequested && available && enabled) adapter.discovering = true
    function scan(active) { scanningRequested = active; if (available && enabled) adapter.discovering = active; }
    function connectDevice(device) {
        if (devices.indexOf(device) < 0) return;
        error = ""; pendingDevice = device;
        expectation = device.connected ? "disconnected" : device.paired ? "connected" : "paired";
        if (device.connected) device.disconnect(); else if (device.paired) device.connect(); else device.pair();
        verify.restart();
    }
}
