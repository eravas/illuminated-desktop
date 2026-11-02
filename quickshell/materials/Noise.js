.pragma library
// Dither thresholds and noise (DESIGN-SYSTEM.md §3.5a). The ordered 8×8 matrix on the
// logical-pixel grain (gc = round(pixel.logical × D) device px), interleaved-gradient noise,
// hashed value noise. Pure functions; no state.

var BAYER = (function () {
    var m = [[0, 2], [3, 1]];
    for (var n = 2; n < 8; n *= 2) {
        var r = [];
        for (var y = 0; y < 2 * n; y++) {
            r[y] = [];
            for (var x = 0; x < 2 * n; x++) {
                var q = (y < n ? 0 : 2) + (x < n ? 0 : 1);
                r[y][x] = 4 * m[y % n][x % n] + [0, 2, 3, 1][q];
            }
        }
        m = r;
    }
    var out = new Float32Array(64);
    for (var i = 0; i < 64; i++) out[i] = (m[i >> 3][i & 7] + 0.5) / 64;
    return out;
})();
// Ordered threshold for grain cell (gx, gy), in (0, 1).
function thr(gx, gy) { return BAYER[((gy & 7) << 3) | (gx & 7)]; }
// Threshold for a device pixel.
function thrPx(x, y, gc) { return BAYER[(((y / gc) | 0) & 7) << 3 | (((x / gc) | 0) & 7)]; }
// Interleaved-gradient noise (Jimenez): organic, no grid.
function ign(x, y) { var v = 52.9829189 * ((0.06711056 * x + 0.00583715 * y) % 1); return v - Math.floor(v); }
function grain(pixelLogical, dpr) { return Math.max(1, Math.round((pixelLogical || 1) * (dpr || 1))); }

function h2(x, y) {
    var n = Math.imul(x | 0, 374761393) ^ Math.imul(y | 0, 668265263);
    n = Math.imul(n ^ (n >>> 13), 1274126177);
    return ((n ^ (n >>> 16)) >>> 0) / 4294967296;
}
function sm(t) { return t * t * (3 - 2 * t); }
function vn(x, y) {
    var xi = Math.floor(x), yi = Math.floor(y), fx = sm(x - xi), fy = sm(y - yi);
    var a = h2(xi, yi), b = h2(xi + 1, yi), c = h2(xi, yi + 1), d = h2(xi + 1, yi + 1);
    return a + (b - a) * fx + (c - a) * fy + (a - b - c + d) * fx * fy;
}
// Seeded value noise of the card swatch (copper patina).
function vnoise(x, y, cell, seed) {
    var gx = Math.floor(x / cell), gy = Math.floor(y / cell), fx = x / cell - gx, fy = y / cell - gy;
    function hs(a, b) {
        var t = Math.imul(a, 73856093) ^ Math.imul(b, 19349663) ^ Math.imul(seed, 83492791);
        t = Math.imul(t ^ (t >>> 15), 2246822519); t = Math.imul(t ^ (t >>> 13), 3266489917);
        return ((t ^ (t >>> 16)) >>> 0) / 4294967296;
    }
    var a = hs(gx, gy), b = hs(gx + 1, gy), c = hs(gx, gy + 1), e = hs(gx + 1, gy + 1), u = sm(fx), v = sm(fy);
    return a + (b - a) * u + (c - a) * v + (a - b - c + e) * u * v;
}
