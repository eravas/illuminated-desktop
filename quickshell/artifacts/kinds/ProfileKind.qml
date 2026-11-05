pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Services.UPower
import "../CardModel.js" as CardModel
// Power profile (provisional card): a click cycles the profiles the daemon offers.
CardKind {
    presentation: ({surface: CardModel.plain(card.colours), glyph: "", value: PowerProfiles.profile === PowerProfile.PowerSaver ? "Power saver" : PowerProfiles.profile === PowerProfile.Performance ? "Performance" : "Balanced"})
    function activate() {
        const order = [PowerProfile.PowerSaver, PowerProfile.Balanced].concat(PowerProfiles.hasPerformanceProfile ? [PowerProfile.Performance] : []);
        PowerProfiles.profile = order[(order.indexOf(PowerProfiles.profile) + 1) % order.length];
        return true;
    }
}
