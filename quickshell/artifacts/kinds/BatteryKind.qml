pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io
import Quickshell.Services.UPower
import "../../config"
import "../CardModel.js" as CardModel
// Battery: charge, charging and plugged state; the back ("Charge") has the details.
CardKind {
    id: adapterRoot
    readonly property var battery: UPower.displayDevice
    readonly property bool available: battery && battery.ready && battery.isPresent
    readonly property bool charging: available && battery.state === UPowerDeviceState.Charging
    readonly property bool externalPower: available && !UPower.onBattery && !charging
    readonly property bool batteryFull: externalPower && (battery.state === UPowerDeviceState.FullyCharged || battery.percentage >= 0.995)
    level: available ? battery.percentage : 0
    present: available
    presentation: CardModel.battery({present: available, level: level, charging: charging, plugged: externalPower, full: batteryFull},
                                    card.colours, Settings.lowChargeNumeral)
    back: Component { BatteryBack { card: adapterRoot.card; kind: adapterRoot } }
    readonly property string profileText: PowerProfiles.profile === PowerProfile.PowerSaver ? "Power saver" : PowerProfiles.profile === PowerProfile.Performance ? "Performance" : "Balanced"
    // Time to full while charging, time to empty on battery; nothing to count down on AC otherwise.
    readonly property string remainingText: !available ? "—" : charging ? CardModel.duration(battery.timeToFull) : UPower.onBattery ? CardModel.duration(battery.timeToEmpty) : "—"
    readonly property var laptopBattery: UPower.devices.values.find(d => d.isLaptopBattery) || null
    property string chargeLimit: ""
    FileView {
        // Charge limit where the kernel exposes it; the row is hidden otherwise.
        path: adapterRoot.laptopBattery && adapterRoot.laptopBattery.nativePath ? "/sys/class/power_supply/" + adapterRoot.laptopBattery.nativePath + "/charge_control_end_threshold" : ""
        printErrors: false
        onLoaded: { const value = parseInt(text()); adapterRoot.chargeLimit = value > 0 && value < 100 ? value + "%" : value === 100 ? "None" : ""; }
        onLoadFailed: adapterRoot.chargeLimit = ""
    }
}
