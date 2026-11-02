.pragma library
.import "Noise.js" as Noise
.import "Colour.js" as Colour
.import "Pixels.js" as Pixels
.import "Fields.js" as Fields
// Card faces as material (DESIGN-SYSTEM.md §3.5a–§3.9a): cardstock, level washes and foils
// with their level mark, copper oxidising to verdigris, bands, chin fills, tonal back interiors,
// the art panel (placeholder colour or your art's pixels, with its dither grain), rounded
// corners, the dog-ear cut, the low-charge numeral halo, and the device card's silver fill.

// ── Foil ────────────────────────────────────────────────────────────────────
// Level-independent sheen field per face size and grain, cached: band sum, glint candidates
// and the glint noise. Band centres along u = 0.75·x/w + 0.45·y/h: 0.42 (main, 0.09),
// 0.78 (faint, 0.04), 1.06 (right, 0.075, amplitude 1.2). §3.5a.
var sheenCache = {}, sheenKeys = [], sheenFields = -1;
function sheen(W, H, gc) {
    if (sheenFields !== Fields.fieldsVersion()) { sheenCache = {}; sheenKeys = []; sheenFields = Fields.fieldsVersion(); }
    var key = W + "x" + H + "@" + gc;
    if (sheenCache[key]) return sheenCache[key];
    var n = W * H, S = new Float32Array(n), G = new Uint8Array(n), N = new Float32Array(n);
    for (var y = 0; y < H; y++) {
        var qy = Math.floor(y / gc) * gc;
        for (var x = 0; x < W; x++) {
            var qx = Math.floor(x / gc) * gc, u = qx / W * 0.75 + qy / H * 0.45, i = y * W + x;
            if (Fields.field("sheen")) {
                var sp = Fields.field("sheen"), span = sp.span || 1.2, k = Math.max(0, Math.min(sp.w - 1, Math.round(u / span * (sp.w - 1))));
                S[i] = sp.r[k] * 2; G[i] = sp.g[k] > 0.5 ? 1 : 0;
            } else {
                var b1 = Math.exp(-Math.pow((u - 0.42) / 0.09, 2)), b2 = Math.exp(-Math.pow((u - 0.78) / 0.04, 2)), b3 = Math.exp(-Math.pow((u - 1.06) / 0.075, 2));
                S[i] = 1.5 * b1 + 0.7 * b2 + 1.2 * b3;
                G[i] = b1 > 0.55 || b3 > 0.6 ? 1 : 0;
            }
            N[i] = Fields.field("glint") ? Fields.fieldAt(Fields.field("glint"), "r", qx / gc, qy / gc) : Noise.ign(qx / gc * 3.1, qy / gc * 1.7);
        }
    }
    var entry = {S: S, G: G, N: N};
    sheenCache[key] = entry; sheenKeys.push(key);
    while (sheenKeys.length > 8) delete sheenCache[sheenKeys.shift()];   // a handful of card sizes
    return entry;
}
// Sheen strength follows level: 0.25 + 0.75 × level (eased), §3.5a.
function sheenAmp(level) { return 0.25 + 0.75 * Math.max(0, Math.min(1, level)); }
// Burnish: darker toward the fill boundary; fades out between 95 % and 100 %.
function burnAmount(level) { return Math.min(1, Math.max(0, (1 - level) * 20)); }
// Tone index (0..3) of foil at pixel i (x, y). dist = device px inside the fill from its boundary.
function foilIndex(sf, i, x, y, gc, amp, burn, dist, D) {
    var tv = 1 + amp * sf.S[i];
    if (burn > 0 && dist < 16 * D) tv -= 1.1 * burn * (1 - Math.max(0, dist) / (16 * D));
    if (amp > 0.35 && sf.G[i] && sf.N[i] > 1 - 0.035 * amp) tv = 9;
    var t = Math.floor(tv + Noise.thrPx(x, y, gc));
    return t < 0 ? 0 : t > 3 ? 3 : t;
}

// ── Card faces ──────────────────────────────────────────────────────────────
// Copper oxidising to verdigris (Network connected), stage 1–4. inChin: the darkest copper
// is kept out of text areas. Card swatch, copperAt().
var PATINA_THRESHOLD = [0, 0.17, 0.26, 0.36, 0.80];
function copperAt(x, y, w, h, D, gc, stage, inChin, rim) {
    var ex = Math.min(x, w - 1 - x, y, h - 1 - y) / (Math.min(w, h) * 0.5);
    var P = Fields.field("patina"), n = P ? Fields.fieldAt(P, "r", x / D, y / D) : Noise.vnoise(x, y, 26 * D, 7) * 0.6 + Noise.vnoise(x, y, 11 * D, 13) * 0.4;
    var m = ex * 0.55 + n * 0.45, T = PATINA_THRESHOLD[stage] || 0, t = Noise.thrPx(x, y, gc);
    if (m + (t - 0.5) * 0.08 < T) {
        // Colour-vision rim: a darker patina line where the patina meets the copper.
        if (rim && m + (t - 0.5) * 0.08 > T - 0.025) return Colour.ramp("copper")[0];
        var pn = P ? Fields.fieldAt(P, "g", x / D, y / D) : Noise.vnoise(x, y, 22 * D, 29);
        return Colour.ramp("patina")[Math.max(0, Math.min(2, Math.floor(0.5 + (pn - 0.5) * 1.6 + t)))];
    }
    var u = x / w * 0.75 + y / h * 0.45, band = Math.exp(-Math.pow((u - 0.42) / 0.1, 2));
    return Colour.ramp("copper")[Math.max(inChin ? 1 : 0, Math.min(3, Math.floor(1 + 1.3 * band + t)))];
}

// Card face geometry in device px (CardModel.layout scaled by D).
function cardGeometry(Wd, Hd, D) {
    var k = Math.min(Wd, Hd) / D / 154;
    var frame = Math.max(4, Math.round(10 * k)) * D;
    var chin = Math.round(Hd / D * (Wd > Hd ? 0.2 : 0.19)) * D;
    return {k: k, frame: frame, chin: chin, bottom: Hd - chin, radius: 0.055 * Math.min(Wd, Hd), artRadius: 0.055 * Math.min(Wd - 2 * frame, Hd - chin - frame)};
}

// spec (all colours "#rrggbb" or [r,g,b]):
//   D, gc, front, base, edge, ink (unused here; text is live), onFill
//   art: {rgb, luminance, saturation, pixels?}         front only; flat placeholder, or your art
//        (pixels: RGBA of the art rect, (Wd − 2·frame) × (chin top − frame) device px)
//   wash: {colour | foil: "gold"|"silver"|..., level, axis "x"|"y", mark: "dither"|"line"|"solid", line}
//   bands: {colour}; chinFill: {colour, bleed}; copper: {stage, rim}; hatch: {colour} (colour vision)
//   interior: {base | null, stripe, washStripe}        backs only (tonal bands)
//   cut: device px of the dog-ear corner cut away (0 = none)
function paintCard(px, Wd, Hd, s) {
    var D = s.D || 1, gc = s.gc || 1, g = cardGeometry(Wd, Hd, D), mg = g.frame, bot = g.bottom;
    var base = Colour.rgb(s.base), edge = Colour.rgb(s.edge), w = s.wash, wf = w && !w.foil ? Colour.rgb(w.colour) : null;
    var lv = w ? Math.max(0, Math.min(1, w.level)) : 0, full = lv >= 0.999, spread = 12 * D * (s.k || g.k || 1);
    var bx = Wd * lv, ly = Hd - Hd * lv, horiz = w && w.axis !== "y";
    var sf = w && w.foil ? sheen(Wd, Hd, gc) : null, F = w && w.foil ? Colour.ramp(w.foil) : null, amp = w && w.foil ? sheenAmp(lv) : 0, burn = w && w.foil ? burnAmount(lv) : 0;
    var mark = w ? w.mark || "dither" : "dither", lineCol = w ? Colour.rgb(w.line || (w.foil ? Colour.ramp(w.foil)[0] : Colour.mixLab(w.colour, s.onFill || "#211C15", 0.45))) : null;
    var period = 18 * D * Math.max(0.6, g.k), bands = s.bands ? Colour.rgb(s.bands.colour) : null;
    var chinFill = s.chinFill ? Colour.rgb(s.chinFill.colour) : null, bleed = s.chinFill && s.chinFill.bleed, E = 9 * D * Math.max(0.6, g.k);
    var it = s.interior, itBase = it && it.base ? Colour.rgb(it.base) : null, itStripe = it ? Colour.rgb(it.stripe) : null, itWash = it ? Colour.rgb(it.washStripe) : null;
    var art = s.front && s.art ? s.art : null, artRGB = art ? Colour.rgb(art.rgb || "#808080") : null, artLum = art ? (art.luminance === undefined ? 1 : art.luminance) : 1;
    var artSat = art ? (art.saturation === undefined ? 1 : art.saturation) : 1, aw = Wd - 2 * mg, ah = bot - mg, ar = g.artRadius;
    var awi = Math.round(aw), ahi = Math.round(ah), mgi = Math.round(mg), artPx = art && art.pixels && art.pixels.length === awi * ahi * 4 ? art.pixels : null;
    var hatch = s.hatch ? Colour.rgb(s.hatch.colour) : null, cut = s.cut || 0, rad = g.radius;
    for (var y = 0; y < Hd; y++) {
        for (var x = 0; x < Wd; x++) {
            var i = (y * Wd + x) * 4;
            var cov = Pixels.rrCov(x + 0.5, y + 0.5, Wd, Hd, rad);
            if (cov <= 0) { px[i + 3] = 0; continue; }
            if (cut > 0 && x - (Wd - cut) > y) { px[i + 3] = 0; continue; }   // dog-ear: the corner is cut away
            var frame = x < mg || x >= Wd - mg || y < mg || y >= Hd - mg, inChin = !frame && y >= bot, inArt = !frame && y < bot;
            if (s.front && inArt && art) {
                var ac = Pixels.rrCov(x - mg + 0.5, y - mg + 0.5, aw, ah, ar);
                if (ac > 0) {
                    var r0 = artRGB[0], g0 = artRGB[1], b0 = artRGB[2];
                    var axi = x - mgi, ayi = y - mgi;
                    if (artPx && axi >= 0 && ayi >= 0 && axi < awi && ayi < ahi) {   // your own art (docs/SKINS.md), over the cardstock
                        var ai = (ayi * awi + axi) * 4, aa = artPx[ai + 3] / 255;
                        r0 = artPx[ai] * aa + base[0] * (1 - aa); g0 = artPx[ai + 1] * aa + base[1] * (1 - aa); b0 = artPx[ai + 2] * aa + base[2] * (1 - aa);
                    }
                    var gr = 0.3 * r0 + 0.59 * g0 + 0.11 * b0;
                    r0 = (gr + (r0 - gr) * artSat) * artLum; g0 = (gr + (g0 - gr) * artSat) * artLum; b0 = (gr + (b0 - gr) * artSat) * artLum;
                    if (artPx) {   // the digital grain: 8 levels per channel through the ordered dither
                        var tq = Noise.thrPx(x, y, gc);
                        r0 = Math.min(7, Math.floor(r0 / 255 * 7 + tq)) * 255 / 7; g0 = Math.min(7, Math.floor(g0 / 255 * 7 + tq)) * 255 / 7; b0 = Math.min(7, Math.floor(b0 / 255 * 7 + tq)) * 255 / 7;
                    }
                    if (ac >= 1) { Pixels.put(px, i, Math.round(r0), Math.round(g0), Math.round(b0), Math.round(cov * 255)); continue; }
                    // Anti-aliased art corner over the cardstock.
                    Pixels.put(px, i, Math.round(base[0] + (r0 - base[0]) * ac), Math.round(base[1] + (g0 - base[1]) * ac), Math.round(base[2] + (b0 - base[2]) * ac), Math.round(cov * 255));
                    continue;
                }
            }
            var c = base, wet = false;
            // Level wash or foil: solid to the level mark, dithering outward past it.
            if (w && lv > 0) {
                var t = Noise.thrPx(x, y, gc), dist = horiz ? bx - x : y - ly;   // > 0 inside the fill
                if (full) wet = true;
                else if (mark === "solid") wet = dist > 0;
                else wet = dist > -(1 - t) * spread;
                if (wet) {
                    c = sf ? F[foilIndex(sf, y * Wd + x, x, y, gc, amp, burn, dist, D)] : wf;
                    if (hatch && !sf && ((x + Hd - y) % (6 * D) < 1.5 * D)) c = hatch;   // colour-vision hatch (muted fill)
                }
                if (mark === "line" && !full && dist <= 0 && dist > -Math.max(1, D)) { c = lineCol; wet = true; }
            }
            if (s.copper) c = copperAt(x, y, Wd, Hd, D, gc, s.copper.stage, inChin || !s.front, s.copper.rim);
            if (chinFill) {
                if (inChin) c = chinFill;
                else if (bleed && frame) {
                    var dd = Math.hypot(Math.max(mg - x, 0, x - (Wd - mg - 1)), Math.max(bot - y, 0, y - (Hd - mg - 1)));
                    if (dd < E && Noise.thrPx(x, y, gc) < 1 - dd / E) c = chinFill;
                }
            }
            var stripe = (((x + y) % period) + period) % period < period / 2;
            if (frame && bands && stripe) c = bands;
            // Back interiors: tonal bands so text needs a single ink.
            if (it && !frame) {
                if (itBase) c = stripe ? itStripe : itBase;
                else if (stripe) c = wet ? itWash : itStripe;
            }
            Pixels.put(px, i, c[0], c[1], c[2], Math.round(cov * 255));
        }
    }
    // Hairline paper edge at native resolution, following the rounded outline.
    if (s.edgeLine !== false) for (var yy = 0; yy < Hd; yy++) for (var xx = 0; xx < Wd; xx++) {
        var ii = (yy * Wd + xx) * 4; if (px[ii + 3] === 0) continue;
        var e = Pixels.rrCov(xx + 0.5, yy + 0.5, Wd, Hd, rad) - Pixels.rrCov(xx + 0.5 - D, yy + 0.5 - D, Wd - 2 * D, Hd - 2 * D, Math.max(0, rad - D));
        if (e > 0.05) Pixels.over(px, ii, edge[0], edge[1], edge[2], Math.min(1, e) * 0.85);
    }
}

// Low-charge numeral halo (card swatch giantNumber): mask = alpha (0..255) of the numeral
// drawn white into the same face. Inside the art: ink on the glyph, then a cardstock halo,
// 2 logical px solid, falling off over 22 px (exponent 1.3) through the dither.
function paintNumeralHalo(px, mask, Wd, Hd, o) {
    var D = o.D || 1, gc = o.gc || 1, ink = Colour.rgb(o.ink), card = Colour.rgb(o.card), core = 2 * D, R = 22 * D;
    var x0 = o.x0 | 0, y0 = o.y0 | 0, x1 = o.x1 | 0, y1 = o.y1 | 0, n = Wd * Hd, Dt = new Float32Array(n), S2 = 1.4142;
    for (var i = 0; i < n; i++) Dt[i] = mask[i * 4 + 3] > 127 ? 0 : 1e9;
    for (var y = 0; y < Hd; y++) for (var x = 0; x < Wd; x++) {
        var j = y * Wd + x, v = Dt[j];
        if (x > 0) v = Math.min(v, Dt[j - 1] + 1);
        if (y > 0) { v = Math.min(v, Dt[j - Wd] + 1); if (x > 0) v = Math.min(v, Dt[j - Wd - 1] + S2); if (x < Wd - 1) v = Math.min(v, Dt[j - Wd + 1] + S2); }
        Dt[j] = v;
    }
    for (var yb = Hd - 1; yb >= 0; yb--) for (var xb = Wd - 1; xb >= 0; xb--) {
        var k = yb * Wd + xb, u = Dt[k];
        if (xb < Wd - 1) u = Math.min(u, Dt[k + 1] + 1);
        if (yb < Hd - 1) { u = Math.min(u, Dt[k + Wd] + 1); if (xb < Wd - 1) u = Math.min(u, Dt[k + Wd + 1] + S2); if (xb > 0) u = Math.min(u, Dt[k + Wd - 1] + S2); }
        Dt[k] = u;
    }
    for (var yy = y0; yy < y1; yy++) for (var xx = x0; xx < x1; xx++) {
        var m = yy * Wd + xx, d = Dt[m], c = null;
        if (d === 0) c = ink;
        else if (d < R) { var p = d <= core ? 1 : Math.pow(1 - (d - core) / (R - core), 1.3); if (Noise.thrPx(xx, yy, gc) < p) c = card; }
        if (c) { px[m * 4] = c[0]; px[m * 4 + 1] = c[1]; px[m * 4 + 2] = c[2]; }
    }
}

