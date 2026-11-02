.pragma library
.import "CardFace.js" as CardFace
.import "Colour.js" as Colour
.import "ArtLayers.js" as Art
// CardModel surface descriptor → textured card face (Materials.paintCard), and the
// one-Canvas paint sequence QML uses. DESIGN-SYSTEM.md §3.5a, §3.6, §3.9, §3.9a.

// opts: {D, gc, front, art: {rgb, luminance, saturation}, cut, mark, cvd, onFill, artStrength, cardstock}
function spec(surface, opts) {
    var o = opts || {}, s = surface || {};
    var out = {D: o.D || 1, gc: o.gc || 1, front: !!o.front, base: s.base || "#808080", edge: s.edge || s.base || "#808080",
               onFill: o.onFill || "#211C15", cut: o.cut || 0, wash: null, bands: null, chinFill: null, copper: null, interior: null, hatch: null};
    if (s.wash && s.wash.level > 0) out.wash = {colour: s.wash.colour, foil: s.wash.foil, level: s.wash.level, axis: s.wash.axis, mark: o.mark || "dither"};
    if (s.bands) out.bands = {colour: s.bands.colour};
    if (s.chinFill) out.chinFill = {colour: s.chinFill, bleed: !!s.chinBleed};
    if (s.patina && s.patina.stage) out.copper = {stage: s.patina.stage, rim: o.cvd === "protan" || o.cvd === "deutan"};
    if (s.interior) out.interior = {base: s.interior.base, stripe: s.interior.stripe, washStripe: s.interior.washStripe};
    // Colour-vision overrides (§3.9a): hatch the muted fill where pink and muted pink converge.
    if (s.muted && (o.cvd === "protan" || o.cvd === "deutan")) out.hatch = {colour: Colour.mixLab(s.wash ? s.wash.colour : "#CCA4B3", out.onFill, 0.35)};
    if (o.front && o.art) {
        var strength = o.artStrength === undefined ? 1 : o.artStrength;
        out.art = {rgb: o.art.rgb || "#808080", luminance: o.art.luminance, saturation: (o.art.saturation === undefined ? 1 : o.art.saturation) * strength,
                   pixels: o.art.pixels || null};
    }
    return out;
}

// Paint a face into a QML (or HTML) 2D context of W × H device px.
// numeral: null | {text, family, size (device px), ink, card, art: {x, y, w, h} device px}
function paint(ctx, W, H, faceSpec, numeral) {
    if (!(W > 0 && H > 0)) return;
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    ctx.clearRect(0, 0, W, H);
    var mask = null;
    if (numeral && numeral.text) {
        // Draw the numeral white, read it back as the halo's distance-field source.
        ctx.fillStyle = "#ffffff"; ctx.textBaseline = "alphabetic"; ctx.textAlign = "left";
        var big = numeral.size, small = Math.round(big * 0.34);
        ctx.font = big + "px \"" + numeral.family + "\"";
        var nw = ctx.measureText(numeral.text).width;
        ctx.font = small + "px \"" + numeral.family + "\"";
        var pw = ctx.measureText("%").width, total = nw + 2 * faceSpec.D + pw;
        var x0 = numeral.art.x + numeral.art.w / 2 - total / 2, base = numeral.art.y + numeral.art.h / 2 + big * 0.36;
        ctx.font = big + "px \"" + numeral.family + "\""; ctx.fillText(numeral.text, x0, base);
        ctx.font = small + "px \"" + numeral.family + "\""; ctx.fillText("%", x0 + nw + 2 * faceSpec.D, base);
        mask = ctx.getImageData(0, 0, W, H).data;
        ctx.clearRect(0, 0, W, H);
    }
    var img = ctx.createImageData(W, H), px = img.data;
    CardFace.paintCard(px, W, H, faceSpec);
    if (mask) CardFace.paintNumeralHalo(px, mask, W, H, {D: faceSpec.D, gc: faceSpec.gc, ink: numeral.ink, card: numeral.card,
        x0: numeral.art.x, y0: numeral.art.y, x1: numeral.art.x + numeral.art.w, y1: numeral.art.y + numeral.art.h});
    ctx.putImageData(img, 0, 0, 0, 0, W, H);
}

// The art panel of a W × H device-px face: its rect in device px.
function artRect(W, H, D) { var g = CardFace.cardGeometry(W, H, D), f = Math.round(g.frame); return {x: f, y: f, w: Math.round(W - 2 * g.frame), h: Math.round(g.bottom - g.frame)}; }
// Your own card art (docs/SKINS.md), cover-fitted into the art panel around `focus` and read back
// as the panel's pixels. aspect = image height / width. The image must be loaded in the canvas.
function rasteriseArt(ctx, W, H, D, url, aspect, focus) {
    var r = artRect(W, H, D), c = Art.cover(aspect, r.w, r.h, focus);
    var full = Art.rasterise(ctx, W, H, 1, url, r.x + c.x, r.y + c.y, c.w, c.h), px = new Uint8ClampedArray(r.w * r.h * 4);
    for (var y = 0; y < r.h; y++) for (var x = 0; x < r.w * 4; x++) px[y * r.w * 4 + x] = full[((y + r.y) * W + r.x) * 4 + x];
    return px;
}
