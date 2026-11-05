import Quickshell
import QtQuick
import "compositors"
import Quickshell.Io
import "components"
import "config"
import "artifacts"
import "services"
import "skin"
ShellRoot {
    id: root
    FeatureLoader { active: Settings.ready && Settings.option("features.wallpaper"); source: "wallpaper.qml" }
    FeatureLoader { active: Settings.ready && (Settings.enableRail || Settings.enableDock); source: "chrome-entry.qml" }
    FeatureLoader { id: launcher; active: Settings.ready && Settings.option("features.launcher"); source: "tools/Launcher.qml" }
    FeatureLoader { active: Settings.ready && Settings.enableCards; source: "cards.qml" }
    FeatureLoader { active: Settings.ready && Settings.option("features.notifications"); source: "notifications.qml" }
    FeatureLoader { active: Settings.ready && Settings.option("features.osd"); source: "osd.qml" }
    FeatureLoader { active: Settings.ready; source: "prompts.qml" }
    FeatureLoader { id: polkit; active: Settings.ready && Settings.option("features.polkit"); source: "polkit.qml" }
    // Latched: once loaded, the lock is never unloaded (a config reload while locked must not
    // destroy it); turning features.lock off takes effect at the next start.
    property bool lockLatched: false
    readonly property bool lockWanted: Settings.ready && Settings.option("features.lock")
    onLockWantedChanged: if (lockWanted) lockLatched = true
    Component.onCompleted: if (lockWanted) lockLatched = true
    FeatureLoader { active: root.lockLatched; source: "lock.qml" }
    function focusedOutput() { return DesktopState.focusedScreen; }
    function hide() {
        if (launcher.feature) launcher.feature.dismiss();
        Navigation.dismiss(); SessionState.cancel();
    }
    Connections { target: Navigation; function onGroupChanged() { if (Navigation.group && launcher.feature) launcher.feature.dismiss(); } function onLauncherRequested() { if (launcher.feature) launcher.feature.toggle(); } }
    IpcHandler {
        target: "shell"
        function status(): string { return JSON.stringify({appearance: Settings.appearance, ready: Settings.ready, configSource: Settings.source, resolvedPath: Settings.resolvedPath, uiPath: Settings.uiPath, configurationError: Settings.error, configurationNotice: Settings.notice, configurationDiagnostics: Settings.diagnostics, compositor: DesktopState.backend, compositorReady: DesktopState.ready, compositorError: DesktopState.error, model: DesktopState.kind, tray: Settings.option("features.tray"), osd: Settings.option("features.osd"), cards: Settings.enableCards, rail: Settings.enableRail, dock: Settings.enableDock, media: Settings.option("features.media"), readingPreset: Settings.readingPreset, reading: Settings.reading, mediaError: RemovableMedia.error, windows: DesktopState.windows.length, launcher: Settings.option("features.launcher"), notifications: NotificationHub.enabled, dnd: NotificationHub.dnd, unread: NotificationHub.unread, historyCount: NotificationHub.history.length, artifacts: Navigation.group, launcherOpen: launcher.feature ? launcher.feature.opened : false, audio: AudioState.available, microphone: AudioState.micAvailable, network: NetworkState.available, bluetooth: BluetoothState.available, backlight: BrightnessState.available, polkit: Settings.option("features.polkit"), polkitRegistered: polkit.feature ? polkit.feature.registered : false, lock: Settings.option("features.lock")}); }
        function toggleLauncher(): void { if (launcher.feature) launcher.feature.toggle(); }
        function cards(group: string): void {
            if (!Settings.enableCards || !SkinStore.group(group)) return;
            if (launcher.feature) launcher.feature.dismiss();
            Actions.run("deal:" + group, {screen: root.focusedOutput()});
        }
        function history(): void { Actions.run("history", {screen: root.focusedOutput()}); }
        function dnd(): void { NotificationHub.dnd = !NotificationHub.dnd; }
        function minimize(): void { DesktopState.minimizeActive(); }
        function clipboard(): void { Actions.run("clipboard", {screen: root.focusedOutput()}); }
        function media(): string { return JSON.stringify(RemovableMedia.devices.map(d => ({id: d.id, kind: d.kind, label: d.label, mounted: d.mounted, locked: d.locked}))); }
        function volume(delta: real): void { AudioState.setVolume(AudioState.volume + delta); }
        function mute(): void { AudioState.toggleMute(); }
        function microphone(): void { AudioState.toggleMic(); }
        function brightness(delta: real): void { BrightnessState.setValue(BrightnessState.value + delta); }
        function hide(): void { root.hide(); }
    }
}
