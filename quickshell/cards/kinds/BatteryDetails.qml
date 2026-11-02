import QtQuick
import Quickshell.Io
import Quickshell.Services.UPower
import "../../artifacts/CardModel.js" as CardModel
QtObject {
    id: root
    readonly property var battery: UPower.displayDevice
    readonly property bool available: battery && battery.ready && battery.isPresent
    readonly property bool charging: available && battery.state === UPowerDeviceState.Charging
    readonly property bool externalPower: available && !UPower.onBattery && !charging
    readonly property bool full: externalPower && (battery.state === UPowerDeviceState.FullyCharged || battery.percentage >= 0.995)
    readonly property real level: available ? battery.percentage : 0
    readonly property var laptopBattery: UPower.devices.values.find(d => d.isLaptopBattery) || null
    property string chargeLimit: ""
    readonly property string profileText: PowerProfiles.profile === PowerProfile.PowerSaver ? "Power saver" : PowerProfiles.profile === PowerProfile.Performance ? "Performance" : "Balanced"
    readonly property string remainingText: !available ? "—" : charging ? CardModel.duration(battery.timeToFull) : UPower.onBattery ? CardModel.duration(battery.timeToEmpty) : "—"
    property FileView limit: FileView {
        path: root.laptopBattery && root.laptopBattery.nativePath ? "/sys/class/power_supply/" + root.laptopBattery.nativePath + "/charge_control_end_threshold" : ""
        printErrors: false
        onLoaded: { const value = parseInt(text()); root.chargeLimit = value > 0 && value < 100 ? value + "%" : value === 100 ? "None" : ""; }
        onLoadFailed: root.chargeLimit = ""
    }
}
