pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.UPower
import "../services"
import "../config"
import "../artifacts/CardModel.js" as CardModel
// The shell's values a skin reads (docs/SKINS.md, "ShellState"): typed properties, each with its
// own change signal, so an object updates when the one value it shows changes.
Singleton {
    id: root
    readonly property var battery: UPower.displayDevice
    readonly property bool charging: batteryPresent && battery.state === UPowerDeviceState.Charging
    readonly property bool full: batteryPresent && (battery.state === UPowerDeviceState.FullyCharged || battery.percentage >= 0.995)
    readonly property bool external: batteryPresent && !UPower.onBattery

    readonly property real volume: AudioState.muted ? 0 : Math.min(1, AudioState.volume)
    readonly property real volumeRaw: AudioState.volume
    readonly property bool muted: AudioState.muted
    readonly property bool audioAvailable: AudioState.available
    readonly property bool micMuted: AudioState.micMuted
    readonly property real brightness: BrightnessState.value
    readonly property bool brightnessAvailable: BrightnessState.available
    readonly property bool batteryPresent: !!battery && battery.ready && battery.isPresent
    readonly property real batteryLevel: batteryPresent ? battery.percentage : 0
    // "absent" | "chg" (charging) | "full" | "held" (on AC, not charging) | "dis" (discharging)
    readonly property string batteryState: !batteryPresent ? "absent" : charging ? "chg" : external && full ? "full" : external ? "held" : "dis"
    readonly property bool networkConnected: !!NetworkState.connectedNetwork || NetworkState.wiredConnected
    readonly property bool networkWired: NetworkState.wiredConnected
    readonly property int networkStage: networkConnected ? Math.max(1, CardModel.signalStage(NetworkState.strength)) : 0   // 0–4
    readonly property bool networkConnecting: NetworkState.connecting
    readonly property bool networkFailed: NetworkState.failed
    readonly property string networkName: NetworkState.connectedNetwork ? NetworkState.connectedNetwork.name : ""
    readonly property bool bluetoothAvailable: BluetoothState.available
    readonly property bool bluetoothOn: BluetoothState.enabled
    readonly property int bluetoothConnected: BluetoothState.connectedDevices.length
    readonly property bool bluetoothConnecting: BluetoothState.connecting
    readonly property int unread: NotificationHub.unread
    readonly property bool dnd: NotificationHub.dnd
    readonly property int clipboardCount: ClipboardHistory.entries.length
    readonly property bool clipboardEnabled: Settings.option("features.clipboard")
    readonly property bool mediaPresent: MediaState.player !== null
    readonly property bool mediaPlaying: !!MediaState.player && MediaState.player.isPlaying
    readonly property string mediaTitle: MediaState.player ? MediaState.player.trackTitle : ""
    readonly property string mode: Settings.appearance
}
