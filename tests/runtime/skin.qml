import QtQuick
import Quickshell
import Quickshell.Io
import "artifacts"
import "rail"
import "skin"
import "services"
// Test entry for tests/runtime/skin.py: the production rail and dock (QML skin) and the cards.
ShellRoot {
    id: root
    Rail { id: rail; screen: Quickshell.screens[0] }
    Dock { id: dock; screen: Quickshell.screens[0] }
    CardsLayer { id: deck }
    function find(node, name) { if (!node) return null; if (node.objectName === name) return node; for (const c of node.children || []) { const f = find(c, name); if (f) return f; } return null; }
    function item(name) { return find(rail.contentItem, name) || find(dock.contentItem, name) || find(deck.contentItem, name); }
    IpcHandler {
        target: "skin"
        // Where an object is on screen (its box centre), or null when it is absent or hidden.
        function where(name: string): string {
            const inDock = !root.find(rail.contentItem, name) && !!root.find(dock.contentItem, name);
            const i = root.item(name);
            if (!i || !i.visible || i.width <= 0) return "null";
            const p = i.mapToItem(null, i.width / 2, i.height / 2);   // window coordinates
            return JSON.stringify({x: p.x + (inDock ? dock.margins.left : 0), y: p.y, width: i.width, height: i.height, hovered: !!i.hovered, mine: i.mine === true});
        }
        function state(): string {
            const kinds = [];
            for (let n = 0; n < deck.cardItems.count; n++) kinds.push(deck.cardItems.itemAt(n).card.kind);
            return JSON.stringify({group: Navigation.group, sheet: Navigation.sheet, phase: deck.phase, kinds: kinds, volume: AudioState.volume,
                                   available: AudioState.available, tag: rail.tag.visible ? rail.tag.text : "", dnd: NotificationHub.dnd,
                                   cork: !!root.item("cork")});
        }
        function close(): void { Navigation.dismiss(); }
        function paths(): string { return JSON.stringify({config: Quickshell.env("XDG_CONFIG_HOME"), shell: Quickshell.shellDir}); }
    }
}
