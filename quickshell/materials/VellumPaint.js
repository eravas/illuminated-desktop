.pragma library
.import "Noise.js" as Noise
.import "Colour.js" as Colour
.import "Pixels.js" as Pixels
.import "Fields.js" as Fields
// The vellum strip (rail, dock, sheets) and the accent wash (DESIGN-SYSTEM.md §3.13).

// ── Vellum strip (rail, dock, sheets) ───────────────────────────────────────
// o: {x0, y0, w, h: strip rect in device px inside the canvas; D, gc; mode; base, fray, edge;
//     amp: texture amplitude; frayDepth: logical px (6); solidEdge; shadow; offX, offY: logical
//     texture offset so the texture runs unbroken across surfaces}
function paintVellum(px, Wd, Hd, o) {
    var D = o.D || 1, gc = o.gc || 1, base = Colour.rgb(o.base), fray = Colour.rgb(o.fray), edge = Colour.rgb(o.edge || o.fray);
    var x0 = o.x0 | 0, y0 = o.y0 | 0, w = o.w | 0, h = o.h | 0, amp = o.amp === undefined ? Fields.TEXTURE_AMPLITUDE[o.mode] || 0.07 : o.amp;
    var Wc = w / gc, Hc = h / gc, F = Math.max(3, (o.frayDepth || 6) * D / gc), offX = o.offX || 0, offY = o.offY || 0;
    // Baked drop shadow along the solid silhouette, 2 logical px down, ~3 px soft.
    if (o.shadow !== false) {
        var sa = o.mode === "dark" ? 0.42 : 0.28, sdy = 2 * D, sr = 3.5 * D;
        for (var y = 0; y < Hd; y++) for (var x = 0; x < Wd; x++) {
            var dx = Math.max(x0 - x - 0.5, 0, x + 0.5 - (x0 + w)), dy = Math.max(y0 + sdy - y - 0.5, 0, y + 0.5 - (y0 + h + sdy));
            var dd = Math.hypot(dx, dy); if (dd >= sr) continue;
            var k = 1 - dd / sr; Pixels.over(px, (y * Wd + x) * 4, 0, 0, 0, sa * k * k);
        }
    }
    for (var yy = 0; yy < h; yy++) {
        var cy = (yy / gc) | 0;
        for (var xx = 0; xx < w; xx++) {
            var cx = (xx / gc) | 0, p = base, i = ((yy + y0) * Wd + xx + x0) * 4;
            if (o.solidEdge) {
                if (xx === 0 || yy === 0 || xx === w - 1 || yy === h - 1) p = edge;
            } else {
                var d = Math.min(cx + 0.5, Wc - cx - 0.5, cy + 0.5, Hc - cy - 0.5);
                if (d < F) { var kk = d / F; if (kk * kk <= Fields.frayAt(cx, cy)) continue; if (d < F * 0.45) p = fray; }
            }
            var f = 1 + Fields.tex((xx) / D + offX, (yy) / D + offY) * 2 * amp;
            Pixels.put(px, i, Math.min(255, Math.round(p[0] * f)), Math.min(255, Math.round(p[1] * f)), Math.min(255, Math.round(p[2] * f)), 255);
        }
    }
}

// Wash tone: accent mixed toward the vellum in OKLab (medium tint: 40 % light, 51 % dark),
// then backed off until mode ink passes 4.5:1 across the texture range (runtime gate, §3.13).
var WASH_STRENGTH = {strong: {light: 0.48, dark: 0.6}, medium: {light: 0.40, dark: 0.51}, soft: {light: 0.32, dark: 0.42}};
function washTone(paper, accent, ink, mode, strength, amp) {
    var k = (WASH_STRENGTH[strength] || WASH_STRENGTH.medium)[mode === "dark" ? "dark" : "light"];
    var a = amp === undefined ? Fields.TEXTURE_AMPLITUDE[mode] || 0.07 : amp;
    for (; k > 0.05; k -= 0.02) {
        var t = Colour.mixLab(paper, accent, k);
        if (Math.min(Colour.contrast(Colour.scaled(t, 1 - a), ink), Colour.contrast(Colour.scaled(t, 1 + a), ink)) >= 4.5) return {tone: t, strength: k};
    }
    return {tone: Colour.rgb(paper), strength: 0};
}
// o: {x0, y0, w, h: wash rect in device px; tone; horizontal; radius (device px); D, gc, amp, mode,
//     solid: 0.2, fade: 0.75 (fractions of the length); edge: logical px (6); offX, offY}
function paintWash(px, Wd, Hd, o) {
    var D = o.D || 1, gc = o.gc || 1, T = Colour.rgb(o.tone), x0 = o.x0 | 0, y0 = o.y0 | 0, w = o.w | 0, h = o.h | 0;
    var Wc = w / gc, Hc = h / gc, r = o.radius === undefined ? 9 * D : o.radius, amp = o.amp === undefined ? Fields.TEXTURE_AMPLITUDE[o.mode] || 0.07 : o.amp;
    var solid = o.solid === undefined ? 0.2 : o.solid, fade = o.fade === undefined ? 0.75 : o.fade, E = Math.max(2, (o.edge || 6) * D / gc);
    var offX = o.offX || 0, offY = o.offY || 0;
    for (var y = 0; y < h; y++) {
        var cy = (y / gc) | 0;
        for (var x = 0; x < w; x++) {
            var a = Pixels.rrCov(x + 0.5, y + 0.5, w, h, r); if (a <= 0) continue;
            var cx = (x / gc) | 0, u = o.horizontal ? (cx + 0.5) / Wc : (cy + 0.5) / Hc;
            var q = Math.min(1, Math.max(0, (u - solid) / fade));
            var dc = Math.min(cx + 0.5, Wc - cx - 0.5, cy + 0.5, Hc - cy - 0.5), cov = (1 - q) * Math.min(1, dc / E);
            if (cov <= Noise.thr(cx, cy)) continue;
            var f = 1 + Fields.tex((x + x0) / D + offX, (y + y0) / D + offY) * 2 * amp;
            Pixels.over(px, ((y + y0) * Wd + x + x0) * 4, Math.min(255, Math.round(T[0] * f)), Math.min(255, Math.round(T[1] * f)), Math.min(255, Math.round(T[2] * f)), a);
        }
    }
}

