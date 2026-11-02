.pragma library
.import "../../../quickshell/materials/Noise.js" as Noise
.import "../../../quickshell/materials/Colour.js" as Colour
.import "../../../quickshell/materials/Pixels.js" as Pixels
// Painters for the default skin's selection images and the initial ground (build-materials.cjs).
// Not loaded by the shell.

// ── Illuminated initials (rail icons) ───────────────────────────────────────
// o: {kind: "plain" | "levels" | "battery" | "connections", level (0..1), stage (0..4), D, gc}
// Gold foil ground, no frame; the edge dissolves into the rail through the dither.
function paintInitial(px, W, H, o) {
    var D = o.D || 1, gc = o.gc || 1, gold = Colour.ramp("gold"), pink = Colour.ramp("pink"), green = Colour.ramp("green"), cu = Colour.ramp("copper"), pa = Colour.ramp("patina");
    var verd = [pa[0], pa[1], pa[2], pa[2]], bd = Math.round(2 * D), kind = o.kind || "plain", lv = Math.max(0, Math.min(1, o.level || 0)), stage = o.stage || 0;
    var F = 3.2 * D;
    for (var y = 0; y < H; y++) for (var x = 0; x < W; x++) {
        var i = (y * W + x) * 4, t = Noise.thrPx(x, y, gc);
        var ed = Math.min(x + 0.5, W - x - 0.5, y + 0.5, H - y - 0.5);
        if (ed < F && ed / F <= t) { px[i + 3] = 0; continue; }
        var qx = Math.floor(x / gc) * gc, qy = Math.floor(y / gc) * gc, u = qx / W * 0.75 + qy / H * 0.45;
        var b1 = Math.exp(-Math.pow((u - 0.4) / 0.12, 2)), b2 = Math.exp(-Math.pow((u - 1.0) / 0.08, 2));
        var pal = gold, boundary = -1, fy = (H - y) / H;
        if ((kind === "levels" || kind === "battery") && lv > 0 && fy + (1 - t) * 0.1 <= lv + 0.0001) { pal = kind === "levels" ? pink : green; boundary = lv; }
        if (kind === "connections") {
            var inner = H - 2 * bd, yy = (H - bd - y) / inner, bi = Math.min(3, Math.floor(yy * 4));
            var line = Math.abs(yy * 4 - Math.round(yy * 4)) * inner / 4 < 0.9 * D;
            pal = bi < stage && !line ? verd : cu;
        }
        var tv = 1 + 1.4 * b1 + 0.8 * b2;
        if (boundary >= 0) { var dist = (boundary - fy) * H; tv -= 1.0 * Math.max(0, 1 - dist / (5 * D)); }
        if (b1 > 0.6 && Noise.ign(qx / gc * 3.1, qy / gc * 1.7) > 0.965) tv = 9;
        var c = pal[Math.max(0, Math.min(pal.length - 1, Math.floor(tv + t)))];
        Pixels.put(px, i, c[0], c[1], c[2], 255);
    }
}
// ── Brass loupe ─────────────────────────────────────────────────────────────
// Painted over the magnified content (px already holds it, or is transparent).
// o: {band: device px (6 logical), dark, D, shadow: device px below}. W = H + shadow.
// Ring diameter = W; the glass is everything inside R − band. Rail and Dock swatch, markers().
function paintLoupe(px, W, Htot, o) {
    var D = o.D || 1, T = (o.band || 6) * D, R = W / 2, dk = !!o.dark, sh = o.shadow === undefined ? Math.max(1, Math.round(3 * D)) : o.shadow;
    var B = Colour.ramp("brass");
    for (var y = 0; y < Htot; y++) for (var x = 0; x < W; x++) {
        var i = (y * W + x) * 4, cx = x + 0.5 - R, cy = y + 0.5 - R, dist = Math.hypot(cx, cy);
        if (dist > R - 0.5) {   // soft contact shadow below the ring
            var ds = Math.hypot(cx, cy - sh); if (y >= R && ds < R) Pixels.over(px, i, 0, 0, 0, 0.32 * Math.min(1, R - ds));
            continue;
        }
        var EA = Math.min(1, R - dist + 0.5), nx = cx / (dist || 1), ny = cy / (dist || 1), c;
        if (dist < R - T) {
            var k = dist / (R - T), Ci = Math.min(1, R - T - dist + 0.5);
            Pixels.over(px, i, 255, 255, 255, 0.05);                                  // the glass lifts its content slightly
            Pixels.over(px, i, 0, 0, 0, 0.22 * Math.pow(k, 6) * (dk ? 1.4 : 1));    // vignette toward the rim
            var hl = Math.hypot(cx + R * 0.32, cy + R * 0.36) / (R * 0.34);
            if (hl < 1) Pixels.over(px, i, 255, 255, 255, (dk ? 0.22 : 0.38) * Math.pow(1 - hl, 1.4));
            var rim = Math.abs(k - 0.9); if (rim < 0.06 && nx + ny < -0.4) Pixels.over(px, i, 255, 255, 255, 0.35 * (1 - rim / 0.06));
            if (Ci < 1) { c = Colour.rampAt(B, 1.2 - 1.5 * (nx * 0.6 + ny * 0.8)); Pixels.over(px, i, c[0], c[1], c[2], 1 - Ci); }
            continue;
        }
        var tt = (dist - (R - T)) / T, lit = -(nx * 0.6 + ny * 0.8);
        c = Colour.rampAt(B, 1.7 + 1.3 * lit - 1.1 * Math.pow(Math.abs(tt - 0.45), 1.5) * 2);
        Pixels.over(px, i, c[0], c[1], c[2], EA);
    }
}
// Plain brass ring with a solid inner ring (Accessibility loupe): no glass, no magnification.
function paintRing(px, W, H, o) {
    var D = o.D || 1, T = (o.band || 6) * D, R = W / 2, ink = Colour.rgb(o.ink || "#211C15");
    for (var y = 0; y < H; y++) for (var x = 0; x < W; x++) {
        var dist = Math.hypot(x + 0.5 - R, y + 0.5 - R), i = (y * W + x) * 4;
        if (dist > R) continue;
        if (dist >= R - T) { var c = Colour.rampAt(Colour.ramp("brass"), 2); Pixels.over(px, i, c[0], c[1], c[2], Math.min(1, R - dist + 0.5)); }
        else if (dist >= R - T - 2 * D) Pixels.over(px, i, ink[0], ink[1], ink[2], 1);
    }
}

