import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import Quickshell.Io
import "artifacts"
import "tools"
import "services"
import "config"
ShellRoot {
    id: root
    Component.onCompleted: {
        Settings.lockCommand = ["sh", "-c", "touch /project/artifacts/development/lock-substitute"];
        Settings.logoutCommand = ["sh", "-c", "touch /project/artifacts/development/logout-substitute"];
        Settings.powerCommands = ({suspend: ["sh", "-c", "test -f /project/artifacts/development/lock-substitute && touch /project/artifacts/development/suspend-substitute"], reboot: ["sh", "-c", "touch /project/artifacts/development/reboot-substitute"], poweroff: ["sh", "-c", "touch /project/artifacts/development/poweroff-substitute"]});
    }
    property bool gestureOpened: false
    property int clicks: 0
    property real gestureValue: 0.5
    property real startValue: 0.5
    CardsLayer { id: deck }
    Launcher { id: launcher }
    Loader { source: "notifications.qml" }
    PanelWindow {
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.namespace: "illuminated-gesture-fixture"
        WlrLayershell.layer: WlrLayer.Overlay
        visible: root.gestureOpened
        ArtifactCard {
            id: probe
            x: 60; y: 100; width: 150
            naturalRotation: 0
            direct: true
            front: Component { Rectangle { color: "#eee3cc" } }
            back: Component { Rectangle { color: "#9ac4a3" } }
            onActivated: root.clicks++
            onDragStarted: root.startValue = root.gestureValue
            onAdjusted: function(delta) { root.gestureValue = Math.max(0, Math.min(1, root.startValue + delta)); }
            onStepped: function(delta) { root.gestureValue = Math.max(0, Math.min(1, root.gestureValue + delta * .05)); }
        }
    }
    IpcHandler {
        target: "test"
        function group(name: string, lane: real): void { launcher.dismiss(); Navigation.open(name, Quickshell.screens[0], lane, "top"); }   // v6 geometry; rail hands: function hand()
        function hand(name: string, lane: real): void { launcher.dismiss(); Navigation.open(name, Quickshell.screens[0], lane, "left"); }
        function close(): void { Navigation.dismiss(); launcher.dismiss(); }
        function page(delta: int): void { deck.turnPage(delta); }
        function select(index: int): void { deck.selectedIndex = index; }
        function flip(index: int): void { const item = deck.cardItems.itemAt(index); if (item) item.card.flipped = !item.card.flipped; }
        function expand(name: string): void { Navigation.expand(name); }
        function launch(): void { launcher.toggle(); }
        function motion(reduced: bool): void { Settings.reducedMotion = reduced; }
        function buttonPoint(index: int, label: string): string { function find(node) { if(node.text === label && node.visible && node.enabled) { const p=node.mapToItem(deck.contentItem,node.width/2,node.height/2);return {x:p.x,y:p.y,width:node.width,height:node.height}; } for(const child of node.children || []) { const p=find(child);if(p)return p; } return null; } return JSON.stringify(find(deck.cardItems.itemAt(index).card)); }
        // Turning a card back: its dog-ear when it has one, otherwise a click on the desk.
        function dogEarPoint(index: int): string { function find(node) { if (node.objectName === "card-dog-ear" && node.visible) { const p=node.mapToItem(deck.contentItem,node.width/2,node.height/2);return {x:p.x,y:p.y,width:node.width,height:node.height}; } for (const child of node.children || []) { const p=find(child);if(p)return p; } return null; } return JSON.stringify(find(deck.cardItems.itemAt(index).card)); }
        function returnPoint(index: int): string { const ear = JSON.parse(dogEarPoint(index)); return JSON.stringify(ear || {x: 8, y: deck.height - 8, width: 1, height: 1}); }
        function armDelay(ms: int): void { Settings.confirmArmDelay = ms; }
        function confirmTimeout(ms: int): void { Settings.confirmTimeout = ms; }
        function lockReady(ready: bool): void { Settings.lockReturnsWhenReady = ready; }
        // A harmless stand-in for a locker that runs until unlock (like plain hyprlock).
        function blockingLock(): void { Settings.lockCommand = ["sh", "-c", "touch /project/artifacts/v3/blocking-lock-started; sleep 18; touch /project/artifacts/v3/blocking-lock-ended"]; }
        function focus(): string { const nodes=[];function visit(node){ if (node.activeFocus || node.activeFocusOnTab) nodes.push({type:String(node),active:node.activeFocus,tab:node.activeFocusOnTab,visible:node.visible,enabled:node.enabled});for(const child of node.children || [])visit(child); } visit(deck.contentItem);return JSON.stringify(nodes); }
        function gesture(): void { root.gestureOpened = !root.gestureOpened; }
        function media(): void { MediaState.toggle(); }
        function next(): void { MediaState.next(); }
        function trayActivate(): void { if (SystemTray.items.values.length) SystemTray.items.values[0].activate(); }
        function trayMenu(): void {
            if (!SystemTray.items.values.length) return;
            Navigation.open("tray", Quickshell.screens[0], 600, "top"); Navigation.trayItem = SystemTray.items.values[0]; Navigation.expand("tray");
        }
        function session(action: string, confirmed: bool): void { SessionState.select(action); if (confirmed) SessionState.confirm(); else SessionState.cancel(); }
        function failingLock(fail: bool): void { Settings.lockCommand = fail ? ["sh", "-c", "exit 7"] : ["sh", "-c", "touch /project/artifacts/development/lock-substitute"]; }
        function dnd(): void { NotificationHub.dnd = !NotificationHub.dnd; }
        function dismissNotification(id: int): void { NotificationHub.dismiss(id); }
        function invoke(id: int): void { NotificationHub.invoke(id, 0); }
        function state(): string {
            const positions = [];
            for (let i = 0; i < deck.cardItems.count; i++) {
                const item = deck.cardItems.itemAt(i);
                positions.push({x: item.x, y: item.y, width: item.width, height: item.height, kind: item.card.kind, rotation: item.card.naturalRotation, flip: item.card.flipProgress, selected: item.card.selected, armed: item.card.armed, dogEar: item.card.dogEar});
            }
            return JSON.stringify({brightness:{available:BrightnessState.available,value:BrightnessState.value},group: deck.displayGroup, requested: Navigation.group, phase: deck.phase, page: deck.page, pages: deck.layout.pages,
                cards: positions, sheet: Navigation.sheet, launcher: {opened: launcher.opened, progress: launcher.progress, geometry: launcher.geometry, motionState: launcher.motionState},
                media: {count: MediaState.players.length, title: MediaState.player ? MediaState.player.trackTitle : "", playing: MediaState.player && MediaState.player.isPlaying},
                tray: SystemTray.items.values.length,
                session: {pending: SessionState.pending, busy: SessionState.busy, error: SessionState.error},
                clicks: root.clicks, value: root.gestureValue, gestureFlip: probe.flipProgress,
                notifications: {enabled: NotificationHub.enabled, history: NotificationHub.history, popups: NotificationHub.popups.length, dnd: NotificationHub.dnd}});
        }
    }
}
