pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../config"
import "../materials/DeviceGeometry.js" as Geo
import "../materials/DeviceArt.js" as DeviceArt
import "../materials"
// The skin in force (docs/SKINS.md). Its data (skin.json: devices, materials, loupes, card art,
// pins) is the default skin's with yours from Settings.skinDir laid over it key by key; files are
// made absolute against the skin they came from before merging. Its QML (Rail.qml,
// DockChrome.qml, Cards.qml and the objects they use) comes from generated/skin/, where
// `illuminated apply` lays your files over the default's by name. Watches both skin.json files; `version` changes when one is re-saved and
// is part of every image URL, so replaced images are picked up. The first loads do not change
// it: image URLs, and so the decoded material fields, stay the same through startup.
Singleton {
    id: root
    readonly property string defaultDir: String(Qt.resolvedUrl("../skins/default/")).replace(/^file:\/\//, "")
    readonly property string userDir: Settings.skinDir ? Settings.skinDir.replace(/\/$/, "") + "/" : ""
    property var base: ({})
    property var user: ({})
    property int version: 0
    property string userError: ""
    readonly property var manifest: merge(absolutise(base, "file://" + defaultDir), absolutise(user, "file://" + userDir))
    readonly property var errors: userError ? [userError] : []
    onManifestChanged: { registerDevices(); registerMaterials(); if (errors.length) console.warn("illuminated skin:", errors.join("; ")); }
    // Data merges key by key; null removes a key. Arrays replace.
    function isObject(v) { return v !== null && typeof v === "object" && !Array.isArray(v); }
    function merge(a, b) {
        if (b === undefined) return a;
        if (!isObject(a) || !isObject(b)) return b;
        const out = Object.assign({}, a);
        for (const k in b) { if (b[k] === null) delete out[k]; else out[k] = isObject(out[k]) && isObject(b[k]) ? merge(out[k], b[k]) : b[k]; }
        return out;
    }
    function absolutise(v, base) {
        if (Array.isArray(v)) return v.map(x => absolutise(x, base));
        if (isObject(v)) { const o = {}; for (const k in v) o[k] = absolutise(v[k], base); return o; }
        if (typeof v !== "string" || !/\.(png|jpe?g|webp|svg)$/i.test(v)) return v;
        return /^[a-z]+:\/\//i.test(v) ? v : v.charAt(0) === "/" ? "file://" + v : base + v;
    }
    // A skin in the pre-QML format (elements, rail.items, dock.before/after in skin.json) is
    // ignored as a whole: its objects cannot be shown any more. `illuminated apply` says so too.
    function oldFormat(v) { return !!v && (v.elements !== undefined || !!(v.rail && v.rail.items !== undefined) || !!(v.dock && (v.dock.before !== undefined || v.dock.after !== undefined))); }
    // Removable media (docs/SKINS.md, "devices"): images for every kind, and geometry for kinds a
    // skin adds (size + like). The seal and its cracked state are under media.
    function registerDevices() {
        const dev = manifest.devices || {}, images = {}, media = manifest.media || {};
        for (const kind in dev) {
            const d = dev[kind] || {};
            images[kind] = {device: url(d.image), envelope: url(d.envelope)};
            if (d.size || !Geo.DEVICES[kind]) Geo.registerArt(kind, d, null); else Geo.unregisterArt(kind);
        }
        DeviceArt.setImages(images, {seal: url(media.seal), cracked: url(media.sealCracked)});
    }
    // Material images (docs/SKINS.md, "materials") for MaterialFields to install.
    function registerMaterials() {
        const m = manifest.materials || {}, out = {};
        for (const n in m) if (m[n] && m[n].image) out[n] = {url: url(m[n].image), size: m[n].size, span: m[n].span, rows: m[n].rows, lengths: m[n].lengths};
        MaterialFields.sources = out;
    }
    // QML skins (docs/SKINS.md): `illuminated apply` lays your skin's files over the default's
    // in generated/skin/ (one file wins over another by name). Until it has, the default skin.
    readonly property string mergedDir: Settings.readOnly ? "" : Settings.configHome + "/illuminated/generated/skin/"
    property bool merged: false
    readonly property string qmlDir: merged ? mergedDir : defaultDir
    function qml(name) { return "file://" + qmlDir + name; }
    FileView {
        path: root.mergedDir ? root.mergedDir + "Rail.qml" : ""
        watchChanges: true; printErrors: false
        onFileChanged: reload()
        onLoaded: root.merged = true
        onLoadFailed: root.merged = false
    }
    // The skin's Cards.qml (optional): its cards and hands, by name. Reactive: a card or hand
    // a skin adds appears without a restart.
    property var skinCards: ({})
    property var skinHands: ({})
    property QtObject cardsObject: null
    function loadCards() {
        if (cardsObject) { cardsObject.destroy(); cardsObject = null; }
        const component = Qt.createComponent(qml("Cards.qml"));
        const cards = {}, hands = {};
        if (component.status === Component.Ready) {
            cardsObject = component.createObject(root);
            for (const e of (cardsObject ? cardsObject.entries : [])) {
                if (e.face !== undefined) cards[e.name] = e; else if (e.cards !== undefined) hands[e.name] = e;
            }
        } else if (component.status === Component.Error && !/No such file|does not exist|Cannot open/.test(component.errorString()))
            console.warn("illuminated skin: Cards.qml:", component.errorString());
        skinCards = cards; skinHands = hands;
    }
    onQmlDirChanged: loadCards()
    Component.onCompleted: loadCards()
    // Cards and groups: config first, then the skin's (a card "skin:<name>").
    function card(kind) {
        const own = Settings.card(kind);
        if (own && Object.keys(own).length) return own;
        const s = kind.indexOf("skin:") === 0 ? skinCards[kind.slice(5)] : null;
        return s ? {title: s.title, short: s.short, orientation: s.orientation, skin: true} : {};
    }
    function group(name) {
        const own = Settings.group(name);
        if (own) return own;
        const h = skinHands[name];
        return h ? {label: h.label, glyph: h.glyph, cards: h.cards, sheet: h.sheet, show: h.show} : null;
    }
    // An image file as a URL that changes when the skin reloads (cache-buster).
    function url(file) { return file ? file + "?v=" + version : ""; }
    function parse(text, isUser) {
        try {
            const v = JSON.parse(text);
            if (!v || typeof v !== "object" || Array.isArray(v)) throw new Error("skin.json must be an object");
            if (isUser && oldFormat(v)) { user = {}; userError = userDir + "skin.json is in the old skin format (elements, rail.items, dock); it is ignored. See docs/SKINS.md."; }
            else if (isUser) { user = v; userError = ""; } else base = v;
        } catch (e) {
            if (isUser) { user = {}; userError = userDir + "skin.json: " + e.message; }
            else { console.warn("illuminated: the default skin does not parse:", e.message); registerMaterials(); }
        }
    }
    FileView {
        path: root.defaultDir + "skin.json"
        watchChanges: true; printErrors: true
        onFileChanged: { root.version++; reload(); }
        onLoaded: root.parse(text(), false)
    }
    FileView {
        path: root.userDir ? root.userDir + "skin.json" : ""
        watchChanges: true; printErrors: false
        onFileChanged: { root.version++; reload(); }
        onLoaded: root.parse(text(), true)
        onLoadFailed: function(error) { root.user = {}; root.userError = error === FileViewError.FileNotFound ? "" : root.userDir + "skin.json: " + FileViewError.toString(error); }
    }
}
