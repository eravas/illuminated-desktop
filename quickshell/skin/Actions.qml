pragma Singleton
import QtQuick
import Quickshell
import "../config"
import "../services"
import "../artifacts"
import "../compositors"
// What a skin button can do (docs/SKINS.md, "Actions"). One registry: every trigger in every
// skin goes through run(); labels and availability come from here too, so tags and disabled
// regions agree with what a click would do. Commands are names from config.toml
// [commands.custom], run as "command:<name>". A skin is trusted code like the rest of the rice
// (it is QML): this registry is a convenience, not a security boundary.
Singleton {
    id: root
    // "name" or "name:arg"; null for an unknown action.
    readonly property var names: ["none", "launcher", "deal", "sheet", "notifications", "history", "clipboard", "tray", "mute", "volume", "brightness", "microphone", "workspace", "minimize", "lock", "media", "dnd", "hide", "command"]
    function parse(s) {
        if (typeof s !== "string" || !s) return null;
        const i = s.indexOf(":"), name = i < 0 ? s : s.slice(0, i), arg = i < 0 ? "" : s.slice(i + 1);
        return names.indexOf(name) < 0 ? null : {name: name, arg: arg};
    }
    // ctx: {screen, y (screen y of the item, for dealing)}
    function run(action, ctx) {
        const a = parse(action);
        if (!a || !available(action)) return false;
        const c = ctx || {}, screen = c.screen || DesktopState.focusedScreen;
        switch (a.name) {
        case "none": return true;
        case "launcher": Navigation.launcherRequested(); return true;
        case "deal": return deal(a.arg, screen, c.y);
        case "notifications": return deal("notifications", screen, c.y);
        case "clipboard": return deal("clipboard", screen, c.y);
        case "tray": Navigation.trayItem = null; if (!deal("tray", screen, c.y)) return false; Navigation.expand("tray"); return true;
        case "sheet": if (!Settings.enableCards) return false; Navigation.open(c.group || "notifications", screen, c.y); Navigation.expand(a.arg); return true;
        case "history": if (!deal("notifications", screen, c.y)) return false; Navigation.expand("history"); return true;
        case "mute": AudioState.toggleMute(); return true;
        case "microphone": AudioState.toggleMic(); return true;
        case "volume": AudioState.setVolume(AudioState.volume + step(a.arg)); return true;
        case "brightness": BrightnessState.setValue(BrightnessState.value + step(a.arg)); return true;
        case "workspace": return workspace(a.arg, screen);
        case "minimize": DesktopState.minimizeActive(); return true;
        case "lock": SessionState.select("lock"); return SessionState.confirm();
        case "media": return media(a.arg);
        case "dnd": NotificationHub.dnd = !NotificationHub.dnd; return true;
        case "hide": Navigation.dismiss(); return true;
        case "command": {
            const argv = (Settings.option("commands.custom") || ({}))[a.arg];
            if (!Array.isArray(argv) || !argv.length) { console.warn("illuminated skin: no [commands.custom]." + a.arg); return false; }
            Quickshell.execDetached(argv); return true;
        }
        }
        return false;
    }
    // Whether an action can do anything right now (disabled regions are not drawn or clickable).
    function available(action) {
        const a = parse(action);
        if (!a) return false;
        switch (a.name) {
        case "deal": return Settings.enableCards && !!SkinStore.group(a.arg);
        case "notifications": case "history": return Settings.enableCards;
        case "clipboard": return Settings.enableCards && Settings.option("features.clipboard");
        case "tray": return Settings.enableCards && Settings.option("features.tray");
        case "sheet": return Settings.enableCards;
        case "command": return Array.isArray((Settings.option("commands.custom") || ({}))[a.arg]);
        case "media": return MediaState.player !== null;
        }
        return true;
    }
    // A default tag for an action when the skin gives none.
    function label(action) {
        const a = parse(action);
        if (!a) return "";
        switch (a.name) {
        case "launcher": return "Launcher";
        case "deal": { const g = SkinStore.group(a.arg); return g ? (g.label || a.arg) : a.arg; }
        case "notifications": return "Notifications" + (NotificationHub.unread ? " · " + NotificationHub.unread + " unread" : "") + (NotificationHub.dnd ? " · quiet" : "");
        case "clipboard": return "Clipboard history";
        case "history": return "Notification history";
        case "tray": return "Tray";
        case "mute": return AudioState.muted ? "Unmute" : "Mute";
        case "workspace": return "Workspace " + a.arg;
        case "command": return a.arg;
        case "media": return MediaState.player ? MediaState.player.trackTitle || "Media" : "Media";
        }
        return a.name.charAt(0).toUpperCase() + a.name.slice(1);
    }
    function step(arg) { const v = parseFloat(arg); return isFinite(v) ? v / 100 : 0.05; }
    function deal(name, screen, y) {
        if (!Settings.enableCards || !SkinStore.group(name)) return false;
        Navigation.open(name, screen, y); return true;
    }
    function workspace(arg, screen) {
        const spaces = DesktopState.context(screen ? screen.name : "").spaces || [];
        if (!spaces.length) return false;
        const at = spaces.findIndex(s => s.focused || s.active);
        let target = null;
        if (arg === "next") target = spaces[(at + 1) % spaces.length];
        else if (arg === "previous") target = spaces[(at - 1 + spaces.length) % spaces.length];
        else target = spaces.find(s => String(s.id) === arg || s.name === arg);
        if (!target) return false;
        DesktopState.activate(target, false); return true;
    }
    function media(arg) {
        if (arg === "next") MediaState.next(); else if (arg === "previous") MediaState.previous(); else MediaState.toggle();
        return true;
    }
}
