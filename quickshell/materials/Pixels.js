.pragma library
.import "Noise.js" as Noise
// Pixel arrays (RGBA, non-premultiplied, as Canvas ImageData): writes, source-over, rounded-rect
// coverage, the 7-level dither quantisation and the separable alpha blur used for shadows.

// ── Pixel helpers ───────────────────────────────────────────────────────────
function put(px, i, r, g, b, a) { px[i] = r; px[i + 1] = g; px[i + 2] = b; px[i + 3] = a; }
// Source-over onto a non-premultiplied pixel.
function over(px, i, r, g, b, a) {
    if (a <= 0) return;
    if (a >= 1) { px[i] = r; px[i + 1] = g; px[i + 2] = b; px[i + 3] = 255; return; }
    var A = px[i + 3] / 255, o = a + A * (1 - a);
    px[i] = Math.round((r * a + px[i] * A * (1 - a)) / o);
    px[i + 1] = Math.round((g * a + px[i + 1] * A * (1 - a)) / o);
    px[i + 2] = Math.round((b * a + px[i + 2] * A * (1 - a)) / o);
    px[i + 3] = Math.round(o * 255);
}
// Rounded-rectangle coverage of a pixel centre (anti-aliased, native resolution).
function rrCov(px, py, W, H, r) {
    var ex = Math.min(px, W - px), ey = Math.min(py, H - py);
    if (ex >= r || ey >= r) return Math.max(0, Math.min(1, ex, ey));
    return Math.max(0, Math.min(1, r - Math.hypot(r - ex, r - ey)));
}

// ── Dither quantisation for painted objects (removable media) ───────────────
// Each channel to `levels` steps through the ordered threshold; alpha to on/off.
function quantise(px, W, H, levels, gc) {
    var L = levels - 1;
    for (var y = 0; y < H; y++) for (var x = 0; x < W; x++) {
        var i = (y * W + x) * 4; if (!px[i + 3]) continue;
        var t = Noise.thrPx(x, y, gc);
        for (var c = 0; c < 3; c++) { var v = px[i + c] / 255 * L; px[i + c] = Math.round(Math.min(L, Math.floor(v + t)) * 255 / L); }
        px[i + 3] = px[i + 3] > 127 ? 255 : 0;
    }
}
// Separable box blur of an alpha channel (shadow masks; baked once).
function blurAlpha(px, W, H, radius) {
    var r = Math.max(1, Math.round(radius)), n = W * H, a = new Float32Array(n), b = new Float32Array(n);
    for (var i = 0; i < n; i++) a[i] = px[i * 4 + 3];
    for (var pass = 0; pass < 2; pass++) {
        for (var y = 0; y < H; y++) { var s = 0; for (var x = -r; x <= r; x++) s += a[y * W + Math.max(0, Math.min(W - 1, x))];
            for (var x2 = 0; x2 < W; x2++) { b[y * W + x2] = s / (2 * r + 1); s += a[y * W + Math.min(W - 1, x2 + r + 1)] - a[y * W + Math.max(0, x2 - r)]; } }
        for (var x3 = 0; x3 < W; x3++) { var t = 0; for (var y3 = -r; y3 <= r; y3++) t += b[Math.max(0, Math.min(H - 1, y3)) * W + x3];
            for (var y4 = 0; y4 < H; y4++) { a[y4 * W + x3] = t / (2 * r + 1); t += b[Math.min(H - 1, y4 + r + 1) * W + x3] - b[Math.max(0, y4 - r) * W + x3]; } }
    }
    return a;
}

