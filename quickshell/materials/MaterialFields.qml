pragma Singleton
import QtQuick
import Quickshell
import "Colour.js" as Colour
import "Fields.js" as Fields
// The skin's material images (docs/SKINS.md, "materials"), installed into Fields.js as
// fields: SkinStore sets `sources`; the first RasterCanvas that paints decodes them (in blocks
// the size of its own canvas) and installs them. A canvas does not paint before that (ensure()
// is false), so each paints once, with the skin's materials, instead of first with the
// procedural originals and again when the images arrive. The originals stand in only when the
// images fail, or when the skin has said nothing within `patience` ms.
Singleton {
    id: root
    // name → {url, size: [w, h], span?, rows?, lengths?}
    property var sources: ({})
    property int version: 0
    property string installed: ""
    property bool known: false            // SkinStore has registered the skin's materials
    onSourcesChanged: known = true
    onKnownChanged: version++              // waiting canvases paint now
    readonly property string key: JSON.stringify(sources)
    Timer { interval: 2000; running: !root.known; onTriggered: { root.known = true; root.version++; } }
    function ensure(raster, ctx) {
        if (installed === key) return true;
        if (!known) return false;                       // painted when version changes
        const names = Object.keys(sources).filter(n => sources[n] && sources[n].url && sources[n].size);
        const urls = names.map(n => sources[n].url);
        const got = urls.length ? raster.withImages(urls, () => {
            Fields.clearFields();
            for (const n of names) {
                const s = sources[n], px = read(ctx, raster.deviceWidth, raster.deviceHeight, s.url, s.size[0], s.size[1]);
                if (n === "ramps") Colour.setRamps(px, s.size[0], s.rows || [], s.lengths || []);
                else Fields.setField(n, s.size[0], s.size[1], px, {span: s.span});
            }
            return true;
        }) : {state: "failed"};
        if (got.state === "loading") return false;      // the canvas repaints when they arrive
        if (got.state === "failed") {
            if (urls.length) console.warn("illuminated skin: material images do not load; using the built-in materials");
            Fields.clearFields();
        }
        installed = key; version++;
        return true;
    }
    // An image at its own size, read through a canvas of cw × ch device px, block by block.
    function read(ctx, cw, ch, url, w, h) {
        const out = new Uint8ClampedArray(w * h * 4), bw = Math.max(1, Math.min(w, cw)), bh = Math.max(1, Math.min(h, ch));
        for (let by = 0; by < h; by += bh) for (let bx = 0; bx < w; bx += bw) {
            const sw = Math.min(bw, w - bx), sh = Math.min(bh, h - by);
            ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.clearRect(0, 0, sw, sh);
            ctx.drawImage(url, bx, by, sw, sh, 0, 0, sw, sh);
            const d = ctx.getImageData(0, 0, sw, sh).data;
            for (let y = 0; y < sh; y++) for (let x = 0; x < sw * 4; x++) out[((by + y) * w + bx) * 4 + x] = d[y * sw * 4 + x];
        }
        ctx.clearRect(0, 0, cw, ch);
        return out;
    }
}
