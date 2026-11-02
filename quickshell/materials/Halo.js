.pragma library
.import "Noise.js" as Noise
.import "Colour.js" as Colour
.import "Pixels.js" as Pixels

// ── Focus halo (DESIGN-SYSTEM.md §3.4) ──────────────────────────────────────
// Solid core on the outline; colour runs core → fringe with distance while coverage
// dissolves through the dither. o: {x0, y0, w, h, radius (device px), core, fringe,
// coreWidth (logical px, 2), reach (logical px, 7; 0 = no fringe), D, gc}
function paintHalo(px, W, H, o) {
    var D = o.D || 1, gc = o.gc || 1, C0 = Colour.rgb(o.core), C1 = Colour.rgb(o.fringe), core = (o.coreWidth || 2) * D;
    var R = (o.reach === undefined ? 7 : o.reach) * D, x0 = o.x0, y0 = o.y0, w = o.w, h = o.h, r = o.radius || 0;
    for (var y = 0; y < H; y++) for (var x = 0; x < W; x++) {
        // Distance outside the rounded rectangle.
        var qx = Math.max(x0 + r - (x + 0.5), 0, (x + 0.5) - (x0 + w - r)), qy = Math.max(y0 + r - (y + 0.5), 0, (y + 0.5) - (y0 + h - r));
        var dist = Math.hypot(qx, qy) - r;
        if (dist <= 0) continue;
        var i = (y * W + x) * 4;
        if (dist <= core) { Pixels.over(px, i, C0[0], C0[1], C0[2], Math.min(1, dist + 0.5)); continue; }
        if (R <= 0) continue;
        var t = Math.min(1, Math.max(0, (dist - core) / (R * 0.9)));
        if (Math.exp(-(dist - core) / (R * 0.42)) <= Noise.thrPx(x, y, gc)) continue;
        Pixels.over(px, i, Math.round(C0[0] + (C1[0] - C0[0]) * t), Math.round(C0[1] + (C1[1] - C0[1]) * t), Math.round(C0[2] + (C1[2] - C0[2]) * t), 0.92);
    }
}
