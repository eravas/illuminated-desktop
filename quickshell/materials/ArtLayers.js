.pragma library
.import "Colour.js" as Colour
.import "Noise.js" as Noise
.import "Pixels.js" as Pixels
// Your own art as pixel layers (docs/SKINS.md). Images are drawn once into the canvas at the
// size they will be shown, read back, and cached as pixel arrays by the caller; the canvas can
// then unload the image, so a 3000 px source costs its decoded size only while it is first
// rasterised. Everything after that (ink levels, bands, dither, shadow) is pixel work.

// Draw `url` (already loaded in this canvas) at logical rect x, y, w, h under scale D; return a
// copy of the W × H device-px canvas. Rotation in degrees about the rect's centre, optional.
// src: optional [sx, sy, sw, sh] cell of a sheet, in the image's own pixels.
function rasterise(ctx, W, H, D, url, x, y, w, h, rotation, src) {
    ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.clearRect(0, 0, W, H);
    ctx.save(); ctx.scale(D, D);
    if (rotation) { ctx.translate(x + w / 2, y + h / 2); ctx.rotate(rotation * Math.PI / 180); ctx.translate(-(x + w / 2), -(y + h / 2)); }
    if (src) ctx.drawImage(url, src[0], src[1], src[2], src[3], x, y, w, h);
    else ctx.drawImage(url, x, y, w, h);
    ctx.restore();
    // QML's CanvasPixelArray is not a typed array (no set()): copy by index.
    var d = ctx.getImageData(0, 0, W, H).data, n = W * H * 4, out = new Uint8ClampedArray(n);
    for (var i = 0; i < n; i++) out[i] = d[i];
    ctx.clearRect(0, 0, W, H);
    return out;
}

// src over dst (both W × H RGBA, straight alpha), in place on dst.
function copyInto(dst, src) { for (var i = 0; i < src.length; i++) dst[i] = src[i]; }
function over(dst, src) {
    for (var i = 0; i < dst.length; i += 4) {
        var a = src[i + 3] / 255; if (a <= 0) continue;
        var b = dst[i + 3] / 255, o = a + b * (1 - a);
        for (var c = 0; c < 3; c++) dst[i + c] = Math.round((src[i + c] * a + dst[i + c] * b * (1 - a)) / o);
        dst[i + 3] = Math.round(o * 255);
    }
}

// Ink into a mask: pixels whose mask coverage (alpha × luminance) is > 0 and whose position
// along from → to (device px) is within `level` take ink, shaded by the luminance underneath so
// the art's own highlights carry through. bands: canary diagonal bands over the ink.
function ink(dst, mask, W, H, from, to, level, tones, bands, D) {
    var dx = to[0] - from[0], dy = to[1] - from[1], len2 = dx * dx + dy * dy || 1, period = Math.max(4, Math.round(4 * D * 4));
    var dark = Colour.rgb(tones[0]), mid = Colour.rgb(tones[1]), light = Colour.rgb(tones[2]), canary = Colour.rgb("#FADB2C");
    for (var y = 0; y < H; y++) for (var x = 0; x < W; x++) {
        var i = (y * W + x) * 4, m = mask[i + 3] / 255 * (mask[i] + mask[i + 1] + mask[i + 2]) / 765;
        if (m <= 0.02) continue;
        var t = ((x - from[0]) * dx + (y - from[1]) * dy) / len2;
        if (t < 0 || t > level) continue;
        var lum = dst[i + 3] ? (0.3 * dst[i] + 0.59 * dst[i + 1] + 0.11 * dst[i + 2]) / 255 : 0.5;
        var c = lum < 0.5 ? mix(dark, mid, lum * 2) : mix(mid, light, (lum - 0.5) * 2);
        if (bands && ((x + y) % period) < period * 0.45) c = canary;
        var a = dst[i + 3] / 255, o = m + a * (1 - m);
        for (var k = 0; k < 3; k++) dst[i + k] = Math.round((c[k] * m + dst[i + k] * a * (1 - m)) / o);
        dst[i + 3] = Math.round(o * 255);
    }
}
function mix(a, b, t) { return [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t]; }

// The shell's object finish over finished pixels: quantise to 7 levels through the ordered
// dither, binarise alpha, and add the baked drop shadow (offset in logical px, 40 %).
function finish(px, W, H, D, gc) {
    var n = W * H, alpha = new Uint8ClampedArray(n * 4);
    for (var j = 0; j < n; j++) alpha[j * 4 + 3] = px[j * 4 + 3];
    var shadow = Pixels.blurAlpha(alpha, W, H, 2 * D), ox = Math.round(2 * D), oy = Math.round(2.5 * D);
    Pixels.quantise(px, W, H, 7, gc);
    for (var y = 0; y < H; y++) for (var x = 0; x < W; x++) {
        var i = (y * W + x) * 4;
        if (px[i + 3]) continue;
        var sx = x - ox, sy = y - oy;
        if (sx >= 0 && sy >= 0 && shadow[sy * W + sx] / 255 * 0.4 > Noise.thrPx(x, y, gc)) Pixels.put(px, i, 0, 0, 0, 102);
    }
    return px;
}

// Cover-fit a W × H image box into a w × h rect around a focus point (0..1): the rect to draw.
function cover(aspect, w, h, focus) {
    var f = focus || [0.5, 0.5], dw = w, dh = w * aspect;
    if (dh < h) { dh = h; dw = h / aspect; }
    return {x: (w - dw) * f[0], y: (h - dh) * f[1], w: dw, h: dh};
}

// Hit map from a layer's alpha (> 50 %), grown by `pad` device px so thin shapes stay clickable.
function hitMap(px, W, H, pad) {
    var n = W * H, a = new Uint8Array(n), b = new Uint8Array(n);
    if (!px) return a;
    for (var i = 0; i < n; i++) a[i] = px[i * 4 + 3] > 127 ? 1 : 0;
    if (pad <= 0) return a;
    for (var y = 0; y < H; y++) { var run = -1e9; for (var x = 0; x < W; x++) { if (a[y * W + x]) run = x; b[y * W + x] = x - run <= pad ? 1 : 0; }
        run = 1e9; for (var x2 = W - 1; x2 >= 0; x2--) { if (a[y * W + x2]) run = x2; if (run - x2 <= pad) b[y * W + x2] = 1; } }
    for (var x3 = 0; x3 < W; x3++) { var r2 = -1e9; for (var y3 = 0; y3 < H; y3++) { if (b[y3 * W + x3]) r2 = y3; a[y3 * W + x3] = y3 - r2 <= pad ? 1 : 0; }
        r2 = 1e9; for (var y4 = H - 1; y4 >= 0; y4--) { if (b[y4 * W + x3]) r2 = y4; if (r2 - y4 <= pad) a[y4 * W + x3] = 1; } }
    return a;
}
