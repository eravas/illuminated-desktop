.pragma library
.import "Skin.js" as Skin
.import "../materials/ArtLayers.js" as Px
.import "../materials/Colour.js" as Colour
.import "../materials/Pixels.js" as Pixels
// A skin element's look → finished pixels (docs/SKINS.md). The caller supplies `layer(ref,
// rect)`: the image ref drawn into rect (element units) over the whole canvas, as a W × H RGBA
// array (rasterised once and cached by the caller). Everything else is pixel work here.
//
// Canvas geometry: the element box (units × scale logical px) plus `margin` logical px on every
// side for the shadow; D device px per logical px.

function geometry(size, scale, margin, D) {
    var w = size[0] * scale, h = size[1] * scale;
    return {w: w, h: h, margin: margin, D: D, W: Math.max(1, Math.round((w + 2 * margin) * D)), H: Math.max(1, Math.round((h + 2 * margin) * D)), scale: scale};
}
// A point in element units → device px on the canvas.
function toDevice(g, p) { return [(g.margin + p[0] * g.scale) * g.D, (g.margin + p[1] * g.scale) * g.D]; }

// The frame of a look to draw: an image, or the frame its value selects. Returns a ref or null.
function frameOf(manifest, lk, state, override) {
    if (override) return override;
    if (lk.frames && lk.frames.images) {
        var list = Skin.frames(manifest, lk.frames.images);
        return list.length ? list[Skin.frameIndex(lk.frames, list.length, state)] : null;
    }
    return lk.image ? Skin.image(manifest, lk.image) : null;
}

// o: {manifest, g, look, state, layer, frame (ref, overrides the look's), regions: [{rect,
//     look, frame}], inks: {name: [dark, mid, light]}}. Returns unfinished RGBA.
function compose(o) {
    var g = o.g, W = g.W, H = g.H, px = new Uint8ClampedArray(W * H * 4), lk = o.look, st = o.state || {};
    var base = frameOf(o.manifest, lk, st, o.frame);
    if (base) Px.over(px, o.layer(base, null));
    if (lk.ink && lk.ink.mask) {
        var mask = Skin.image(o.manifest, lk.ink.mask);
        if (mask) {
            var tones = (o.inks || {})[lk.ink.colour || "iron-gall"] || ["#151C30", "#24304F", "#3A4C78"];
            var level = Math.max(0, Math.min(1, Number(Skin.value(st, lk.ink.source)) || 0));
            Px.ink(px, o.layer(mask, null), W, H, toDevice(g, lk.ink.from), toDevice(g, lk.ink.to), level, tones, !!(lk.ink.bands && Skin.test(lk.ink.bands, st)), g.D);
        }
    }
    if (lk.overlay) { var ov = Skin.image(o.manifest, lk.overlay); if (ov) Px.over(px, o.layer(ov, null)); }
    (lk.markers || []).forEach(function (m) {
        if (!Skin.test(m.when, st) || !m.at) return;
        marker(px, W, H, toDevice(g, m.at), (m.radius || 1.3) * g.scale * g.D, m.shape !== "ring", m.colour);
    });
    (o.regions || []).forEach(function (r) {
        var ref = frameOf(o.manifest, r.look, st, r.frame);
        if (ref) Px.over(px, o.layer(ref, r.rect || null));
    });
    return px;
}
// A canary dot (solid) or ring, with a dark rim: shape carries the meaning, not only colour.
function marker(px, W, H, at, R, solid, colour) {
    var c = Colour.rgb(colour || "#FADB2C"), rim = [Math.round(c[0] * 0.44), Math.round(c[1] * 0.41), Math.round(c[2] * 0.2)];
    for (var y = Math.max(0, Math.floor(at[1] - R - 2)); y < Math.min(H, at[1] + R + 2); y++)
        for (var x = Math.max(0, Math.floor(at[0] - R - 2)); x < Math.min(W, at[0] + R + 2); x++) {
            var d = Math.sqrt((x - at[0]) * (x - at[0]) + (y - at[1]) * (y - at[1])), i = (y * W + x) * 4;
            if (d <= R + 1 && d > R - 0.5) Pixels.put(px, i, rim[0], rim[1], rim[2], 255);
            else if (d <= R - 0.5 && (solid || d > R * 0.45)) Pixels.put(px, i, c[0], c[1], c[2], 255);
        }
}
// The shell's finish: dither (7 levels on the logical-px grain) and the baked drop shadow, each
// optional per element ({dither, shadow}; both default on).
function finish(px, g, gc, opts) {
    var o = opts || {};
    if (o.dither === false && o.shadow === false) return px;
    if (o.shadow === false) { Pixels.quantise(px, g.W, g.H, 7, gc); return px; }
    if (o.dither === false) {   // shadow only
        var copy = new Uint8ClampedArray(px.length); copy.set(px);
        Px.finish(copy, g.W, g.H, g.D, gc);
        for (var i = 0; i < px.length; i += 4) if (!px[i + 3] && copy[i + 3]) { px[i] = copy[i]; px[i + 1] = copy[i + 1]; px[i + 2] = copy[i + 2]; px[i + 3] = copy[i + 3]; }
        return px;
    }
    return Px.finish(px, g.W, g.H, g.D, gc);
}
// Alpha of finished pixels (device px), for {alpha: true} hits.
function alpha(px, W, H) { var a = new Uint8Array(W * H); for (var i = 0; i < W * H; i++) a[i] = px[i * 4 + 3] > 127 ? 1 : 0; return a; }
