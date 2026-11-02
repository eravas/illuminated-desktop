pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.UPower
import "../../services"
import "../../config"
import "../../artifacts/CardModel.js" as CardModel
// One adapter object per card. Only its kind's callbacks read service state.
Singleton {
    function profileText() {
        return PowerProfiles.profile === PowerProfile.PowerSaver ? "Power saver" : PowerProfiles.profile === PowerProfile.Performance ? "Performance" : "Balanced";
    }
    function cycleProfile() {
        const order = [PowerProfile.PowerSaver, PowerProfile.Balanced].concat(PowerProfiles.hasPerformanceProfile ? [PowerProfile.Performance] : []);
        PowerProfiles.profile = order[(order.indexOf(PowerProfiles.profile) + 1) % order.length];
    }
    function create(kind, card, views) {
        const flip = () => { if (card.back) card.flipped = !card.flipped; };
        const a = {
            level: () => 0, setLevel: v => false, detail: () => "",
            levelActivate: () => {}, toggle: flip, onOpen: () => {}, onFlip: flipped => {}, cleanup: () => {},
            back: () => card.sessionMode === "act" ? null : card.sessionMode === "menu" ? views.menu : card.sessionMode === "confirm" ? views.confirm : views.generic
        };
        a.step = d => a.setLevel(a.level() + d * 0.05);
        a.activate = () => {
            if (card.spec.interaction === "level") a.levelActivate();
            else if (card.spec.interaction === "toggle") a.toggle();
            else if (card.sessionMode === "act") card.act(kind);
            else flip();
        };
        a.presentation = c => card.power ? CardModel.power(kind, c) : {surface: CardModel.plain(c), glyph: "", value: a.detail()};
        const back = name => () => card.sessionMode === "act" ? null : views[name];
        const kinds = {
            volume: () => {
                a.level = () => AudioState.volume; a.setLevel = v => AudioState.setVolume(v);
                a.levelActivate = () => AudioState.toggleMute(); a.back = back("outputs");
                a.presentation = c => CardModel.level("volume", {available: AudioState.available, level: Math.min(1, a.level()), muted: AudioState.muted}, c);
            },
            microphone: () => {
                a.level = () => AudioState.micVolume; a.setLevel = v => AudioState.setMicVolume(v);
                a.levelActivate = () => AudioState.toggleMic();
                a.presentation = c => CardModel.level("microphone", {available: AudioState.micAvailable, level: Math.min(1, a.level()), muted: AudioState.micMuted}, c);
            },
            brightness: () => {
                a.level = () => BrightnessState.value; a.setLevel = v => BrightnessState.setValue(v); a.back = () => null;
                a.onOpen = () => BrightnessState.read();
                a.presentation = c => CardModel.level("brightness", {available: BrightnessState.available, level: a.level()}, c);
            },
            battery: () => {
                a.level = () => card.batteryDetails ? card.batteryDetails.level : 0; a.back = back("battery");
                a.presentation = c => { const b = card.batteryDetails; return CardModel.battery({present: !!b && b.available, level: a.level(), charging: !!b && b.charging, plugged: !!b && b.externalPower, full: !!b && b.full}, c, Settings.lowChargeNumeral); };
            },
            wifi: () => {
                a.toggle = () => NetworkState.toggle(); a.back = back("network");
                a.onFlip = flipped => NetworkState.scan(flipped); a.cleanup = () => { if (card.flipped) NetworkState.scan(false); };
                a.presentation = c => CardModel.network({enabled: NetworkState.enabled, connecting: NetworkState.connecting, failed: NetworkState.failed, connected: NetworkState.connectedNetwork !== null || NetworkState.wiredConnected, stage: CardModel.signalStage(NetworkState.strength), name: NetworkState.connectedNetwork ? NetworkState.connectedNetwork.name : NetworkState.wiredConnected ? "Wired" : ""}, c);
            },
            bluetooth: () => {
                a.toggle = () => BluetoothState.toggle(); a.back = back("bluetooth"); a.connected = () => BluetoothState.connectedDevices;
                a.presentation = c => { const devices = a.connected(); return CardModel.bluetooth({available: BluetoothState.available, enabled: BluetoothState.enabled, connecting: BluetoothState.connecting, failed: BluetoothState.failed, connected: devices.length, name: devices.length ? devices[0].name : ""}, c); };
            },
            profile: () => { a.toggle = cycleProfile; a.back = () => null; a.presentation = c => ({surface: CardModel.plain(c), glyph: "", value: profileText()}); },
            media: () => { a.detail = () => MediaState.player ? MediaState.player.trackTitle || MediaState.player.identity : "None"; },
            notifications: () => { a.detail = () => NotificationHub.unread + " unread"; },
            dnd: () => { a.toggle = () => { NotificationHub.dnd = !NotificationHub.dnd; }; a.detail = () => NotificationHub.dnd ? "On" : "Off"; },
            outputs: () => { a.back = back("outputs"); a.detail = () => AudioState.sink ? AudioState.sink.description || AudioState.sink.name : "—"; }
        };
        if (kinds[kind]) kinds[kind]();
        return a;
    }
}
