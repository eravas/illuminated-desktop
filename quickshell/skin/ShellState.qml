pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.UPower
import "../services"
import "../config"
import "../artifacts/CardModel.js" as CardModel
// The shell's values that a skin can read (docs/SKINS.md, "Values"): one flat object, so a
// skin's conditions, frame selectors and templates name them as plain strings. Elements repaint
// only when a value they use changes (Skin.sources).
Singleton {
    id: root
    readonly property var battery: UPower.displayDevice
    readonly property bool batteryPresent: !!battery && battery.ready && battery.isPresent
    readonly property bool charging: batteryPresent && battery.state === UPowerDeviceState.Charging
    readonly property bool full: batteryPresent && (battery.state === UPowerDeviceState.FullyCharged || battery.percentage >= 0.995)
    readonly property bool external: batteryPresent && !UPower.onBattery
    readonly property bool networkUp: !!NetworkState.connectedNetwork || NetworkState.wiredConnected
    readonly property var values: ({
        "volume": AudioState.muted ? 0 : Math.min(1, AudioState.volume),
        "volume.raw": AudioState.volume,
        "muted": AudioState.muted,
        "audio.available": AudioState.available,
        "mic.muted": AudioState.micMuted,
        "brightness": BrightnessState.value,
        "brightness.available": BrightnessState.available,
        "battery.present": root.batteryPresent,
        "battery.level": root.batteryPresent ? root.battery.percentage : 0,
        "battery.state": !root.batteryPresent ? "absent" : root.charging ? "chg" : root.external && root.full ? "full" : root.external ? "held" : "dis",
        "network.connected": root.networkUp,
        "network.wired": NetworkState.wiredConnected,
        "network.stage": root.networkUp ? Math.max(1, CardModel.signalStage(NetworkState.strength)) : 0,
        "network.connecting": NetworkState.connecting,
        "network.failed": NetworkState.failed,
        "network.name": NetworkState.connectedNetwork ? NetworkState.connectedNetwork.name : "",
        "bluetooth.available": BluetoothState.available,
        "bluetooth.on": BluetoothState.enabled,
        "bluetooth.connected": BluetoothState.connectedDevices.length,
        "bluetooth.connecting": BluetoothState.connecting,
        "notifications.unread": NotificationHub.unread,
        "notifications.dnd": NotificationHub.dnd,
        "clipboard.count": ClipboardHistory.entries.length,
        "media.present": MediaState.player !== null,
        "media.playing": !!MediaState.player && MediaState.player.isPlaying,
        "media.title": MediaState.player ? MediaState.player.trackTitle : "",
        "time.hour": Time.now.getHours(),
        "time.minute": Time.now.getMinutes(),
        "mode": Settings.appearance
    })
    // Every name a skin may use, for validation and docs.
    readonly property var names: Object.keys(values)
}
