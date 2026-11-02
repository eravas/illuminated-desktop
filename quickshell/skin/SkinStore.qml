pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../config"
import "Skin.js" as Skin
import "Registry.js" as Registry
import "../materials/DeviceGeometry.js" as Geo
import "../materials/DeviceArt.js" as DeviceArt
import "../materials"
// The skin in force (docs/SKINS.md): the default skin shipped with the shell, with yours from
// Settings.skinDir laid over it key by key. Files are made absolute against the skin they came
// from before merging. Watches both skin.json files; `version` changes on every reload and is
// part of every image URL, so replaced images are picked up when you re-save skin.json.
Singleton {
    id: root
    readonly property string defaultDir: String(Qt.resolvedUrl("../skins/default/")).replace(/^file:\/\//, "")
    readonly property string userDir: Settings.skinDir ? Settings.skinDir.replace(/\/$/, "") + "/" : ""
    property var base: ({})
    property var user: ({})
    property int version: 0
    property string userError: ""
    readonly property var manifest: Skin.merge(Skin.absolutise(base, "file://" + defaultDir), Skin.absolutise(user, "file://" + userDir))
    readonly property var errors: Skin.check(manifest).concat(userError ? [userError] : [])
    onManifestChanged: { Registry.set(manifest); version++; registerDevices(); registerMaterials(); if (errors.length) console.warn("illuminated skin:", errors.join("; ")); }
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
    function element(id) { return (manifest.elements || {})[id] || null; }
    // An image file as a URL that changes when the skin reloads (cache-buster).
    function url(file) { return file ? file + "?v=" + version : ""; }
    function parse(text, isUser) {
        try {
            const v = JSON.parse(text);
            if (!v || typeof v !== "object" || Array.isArray(v)) throw new Error("skin.json must be an object");
            if (isUser) { user = v; userError = ""; } else base = v;
        } catch (e) {
            if (isUser) { user = {}; userError = userDir + "skin.json: " + e.message; }
            else console.warn("illuminated: the default skin does not parse:", e.message);
        }
    }
    FileView {
        path: root.defaultDir + "skin.json"
        watchChanges: true; printErrors: true
        onFileChanged: reload()
        onLoaded: root.parse(text(), false)
    }
    FileView {
        path: root.userDir ? root.userDir + "skin.json" : ""
        watchChanges: true; printErrors: false
        onFileChanged: reload()
        onLoaded: root.parse(text(), true)
        onLoadFailed: function(error) { root.user = {}; root.userError = error === FileViewError.FileNotFound ? "" : root.userDir + "skin.json: " + FileViewError.toString(error); }
    }
}
