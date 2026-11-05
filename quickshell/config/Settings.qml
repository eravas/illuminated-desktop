pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "defaults.js" as Packaged
import "Reading.js" as Reading
import "../skin/Registry.js" as SkinRegistry
// Reads configuration; never defines defaults. Values come from, highest first:
//   ui.json (choices made inside the shell, unless config.toml pins the key)
//   resolved.json (config.toml merged over defaults by `illuminated apply`)
//   defaults.js (generated from config/defaults.toml; imported synchronously, so
//   every binding has a value from the first evaluation)
// Paths mirror lib/illuminated/paths.py.
Singleton {
    id: root
    readonly property bool readOnly: Quickshell.env("ILLUMINATED_GREETER") === "1"
    readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config"
    readonly property string resolvedPath: readOnly ? "" : (Quickshell.env("ILLUMINATED_RESOLVED") || configHome + "/illuminated/generated/resolved.json")
    readonly property string uiPath: readOnly ? (Quickshell.env("ILLUMINATED_GREETER_THEME") || "") : (Quickshell.env("ILLUMINATED_SETTINGS") || configHome + "/illuminated/ui.json")
    readonly property var defaults: Packaged.values
    property var resolved: ({})
    property var pinned: []
    property var diagnostics: []
    property var ui: ({})
    property bool resolvedRead: resolvedPath === ""
    property bool uiRead: uiPath === ""
    property bool directoryReady: false
    property string ioError: ""
    // Where resolved.json says the configuration came from (the user's config.toml).
    property string source: ""
    property string notice: ""
    readonly property string error: resolvedFile.problem || uiFile.problem || ioError
    readonly property bool ready: resolvedRead && uiRead
    function parseObject(text) { const value = JSON.parse(text); if (!value || typeof value !== "object" || Array.isArray(value)) throw new Error("Expected JSON object"); return value; }
    function lookup(object, key) { return key.split(".").reduce((value, part) => value !== undefined && value !== null && value[part] !== undefined ? value[part] : undefined, object); }
    function isPinned(key) { return pinned.some(p => p === key || key.startsWith(p + ".") || p.startsWith(key + ".")); }
    function sameType(value, reference) { return reference === undefined || (Array.isArray(reference) ? Array.isArray(value) : typeof value === typeof reference && (typeof value !== "number" || Number.isFinite(value))); }
    function option(key, fallback) {
        const base = lookup(defaults, key);
        let value = isPinned(key) ? undefined : lookup(ui, key);
        if (value === undefined || !sameType(value, base)) value = lookup(resolved, key);
        if (value === undefined || !sameType(value, base)) value = base;
        return value === undefined || value === null ? fallback : value;
    }
    function update(key, value) {
        if (readOnly) return false;
        if (isPinned(key)) { notice = key + " is set in config.toml; change it there"; return false; }
        const result = JSON.parse(JSON.stringify(ui)), parts = key.split(".");
        let cursor = result;
        parts.forEach((part, index) => { if (index === parts.length - 1) cursor[part] = value; else { if (!cursor[part] || typeof cursor[part] !== "object") cursor[part] = {}; cursor = cursor[part]; } });
        ui = result; notice = "";
        if (!directoryReady) { ioError = "Settings directory unavailable"; return false; }
        uiFile.setText(JSON.stringify(ui, null, 2)); return true;
    }
    function color(name) { const value = option("palettes." + appearance + "." + name, undefined); return value !== undefined ? value : lookup(defaults, "palettes.dark." + name); }
    // Registry accessors: cards and groups.
    // Config first; a skin may add cards and hands of its own (docs/SKINS.md).
    function card(kind) { return option("cards." + kind, null) || SkinRegistry.card(kind) || ({}); }
    function group(name) { return option("groups." + name, null) || SkinRegistry.hand(name); }
    readonly property var groups: option("groups", ({}))
    Process { command: ["mkdir", "-p", root.uiPath.substring(0, root.uiPath.lastIndexOf("/"))]; running: !root.readOnly && root.uiPath !== ""; onExited: function(code) { root.directoryReady = code === 0; } }
    FileView {
        id: resolvedFile; property string problem: ""
        path: root.resolvedPath; watchChanges: true; printErrors: false
        onFileChanged: reload()
        onLoaded: {
            root.resolvedRead = true;
            try {
                const value = root.parseObject(text());
                if (value.format !== 1 || !value.values) throw new Error("format");
                root.resolved = value.values; root.pinned = value.pinned || []; root.diagnostics = value.diagnostics || []; root.source = value.source || ""; problem = "";
            } catch (e) { problem = "Unreadable resolved.json; keeping last configuration (run `illuminated apply`)"; }
        }
        onLoadFailed: function(code) { root.resolvedRead = true; if (code === FileViewError.FileNotFound) { root.resolved = ({}); root.pinned = []; problem = ""; } else problem = "Cannot read resolved.json"; }
    }
    FileView {
        id: uiFile; property string problem: ""; path: root.uiPath; watchChanges: true; printErrors: false; atomicWrites: true
        onFileChanged: reload()
        onLoaded: { root.uiRead = true; try { root.ui = root.parseObject(text()); problem = ""; root.ioError = ""; } catch (e) { problem = "Invalid ui.json; keeping last valid choices"; } }
        onLoadFailed: function(code) { root.uiRead = true; if (code === FileViewError.FileNotFound) { root.ui = ({}); problem = ""; } else problem = "Cannot read ui.json"; }
        onSaveFailed: root.ioError = "Cannot save ui.json"
    }
    property string compositor: option("compositor")
    property bool enableCards: option("features.cards")
    property bool enableRail: option("features.rail")
    property bool enableDock: option("features.dock")
    property string wallpaperPath: option("wallpaper.path")
    // Your skin (docs/SKINS.md): skin.json and its images, laid over the default skin.
    readonly property string skinDir: readOnly ? "" : (option("skin.path") || configHome + "/illuminated/skin")
    // Kept as typed properties although they have few readers: each one filters changes for
    // a binding that builds an object, array or model from it (an inline option() would
    // re-run those on every ui.json write; tests/runtime/reload.py times out).
    property var railHands: option("rail.hands")
    property var launcherPins: option("launcher.pins") || []
    property int launcherWidth: option("dimensions.launcherWidth")
    property int launcherHeight: option("dimensions.launcherHeight")
    property int cardWidth: option("deck.width")
    property int landscapeCardWidth: option("deck.landscapeWidth")
    property int cardGap: option("deck.gap")
    property int cardMargin: option("deck.margin")
    property real selectionLift: option("deck.selectionLift")
    property string accent: option("appearance.accent")
    property string washStrength: option("appearance.wash")
    property string legibilityFamily: option("typography.legibility")
    property string blackletterFamily: option("typography.blackletter")
    property string dockMinimizeWorkspace: option("dock.minimizeWorkspace")
    // ── Reading presets and options (DESIGN-SYSTEM.md §3.9) ───────────────
    readonly property string readingPreset: option("reading.preset")
    readonly property var readingOptions: option("reading.options", ({}))
    readonly property var reading: Reading.resolve(readingPreset, readingOptions)
    readonly property bool readingCustom: Reading.isCustom(readingPreset, readingOptions)
    function readingOption(name) { return reading[name]; }
    // ── Rail, dock, removable media ───────────────────────────────────────
    property int railInset: option("rail.inset")
    property int railWidth: option("rail.width")
    // Rail and dock both reserve this much (strip + inset + a small gap), DESIGN-SYSTEM.md §3.13.
    readonly property int railReserved: railInset + railWidth + 5
    readonly property int dockReserved: 8 + railWidth
    // permanent | autohide for one output. Accessibility forces permanent.
    function dockMode(outputName, outputHeight) {
        if (reading.dockAutoHide === "never") return "permanent";
        const own = option("dock.outputs", ({}))[outputName];
        const mode = own || option("dock.mode");
        return mode === "auto" ? (outputHeight > 0 && outputHeight <= 800 ? "autohide" : "permanent") : mode;
    }
    property string mediaScale: option("media.scale")
    property var mediaOverrides: option("media.overrides", ({}))
    property string appearance: option("appearance.mode")
    property bool lowChargeNumeral: reading.lowChargeNumeral === "on"
    property int confirmArmDelay: option("confirm.armDelay")
    property int confirmTimeout: Reading.CONFIRM_TIMEOUT[reading.confirmTimeout] || Reading.CONFIRM_TIMEOUT.normal
    property string fontFamily: option("typography.family")
    property int fontPixelSize: option("typography.size")
    property int smallPixelSize: option("typography.small")
    // Card tilt follows reading.options.rotation (full 4°, reduced 2°); off is grid-aligned.
    property real cardRotation: Reading.CARD_ROTATION[reading.rotation]
    property bool deckAligned: reading.rotation === "off"
    readonly property real typeScale: Reading.TYPE_SCALE[reading.typeScale] || 1
    readonly property int targetSize: Reading.TARGET[reading.targets] || 24
    property bool reducedMotion: option("motion.reduced")
    property var lockCommand: option("commands.lock")
    property bool lockReturnsWhenReady: option("commands.lockReturnsWhenReady")
    property var logoutCommand: option("commands.logout")
    property var powerCommands: ({suspend: option("commands.suspend"), reboot: option("commands.reboot"), poweroff: option("commands.poweroff")})
}
