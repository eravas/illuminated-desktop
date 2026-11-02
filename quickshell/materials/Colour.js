.pragma library
// Colour: sRGB ↔ OKLab, contrast, the material tone ramps (replaced by the skin's ramps image
// through setRamps) and colour-vision simulation. Read ramps with ramp(name): RAMP is
// reassigned, so never keep a reference to it.

// ── Colour ──────────────────────────────────────────────────────────────────
// "#rrggbb", "#aarrggbb" (QML's colour string), [r,g,b] or a QML color (r,g,b in 0..1).
function rgb(c) {
    if (c === undefined || c === null) return [0, 0, 0];
    if (typeof c === "object" && c.length === 3) return c;
    if (typeof c === "object" && c.r !== undefined) return [Math.round(c.r * 255), Math.round(c.g * 255), Math.round(c.b * 255)];
    var s = String(c);
    if (s.length === 9) s = "#" + s.slice(3);
    return [parseInt(s.slice(1, 3), 16), parseInt(s.slice(3, 5), 16), parseInt(s.slice(5, 7), 16)];
}
function css(c) { var p = rgb(c); return "rgb(" + p[0] + "," + p[1] + "," + p[2] + ")"; }
function lin(c) { c /= 255; return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4); }
function unlin(c) { c = c <= 0.0031308 ? 12.92 * c : 1.055 * Math.pow(c, 1 / 2.4) - 0.055; return Math.round(Math.min(1, Math.max(0, c)) * 255); }
function toLab(c) {
    var p = rgb(c), r = lin(p[0]), g = lin(p[1]), b = lin(p[2]);
    var l = Math.cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b);
    var m = Math.cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b);
    var s = Math.cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b);
    return [0.2104542553 * l + 0.793617785 * m - 0.0040720468 * s, 1.9779984951 * l - 2.428592205 * m + 0.4505937099 * s, 0.0259040371 * l + 0.7827717662 * m - 0.808675766 * s];
}
function fromLab(L) {
    var l = Math.pow(L[0] + 0.3963377774 * L[1] + 0.2158037573 * L[2], 3);
    var m = Math.pow(L[0] - 0.1055613458 * L[1] - 0.0638541728 * L[2], 3);
    var s = Math.pow(L[0] - 0.0894841775 * L[1] - 1.291485548 * L[2], 3);
    return [unlin(4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s), unlin(-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s), unlin(-0.0041960863 * l - 0.7034186147 * m + 1.707614701 * s)];
}
// Mix in OKLab: t = 0 → a, 1 → b.
function mixLab(a, b, t) { var p = toLab(a), q = toLab(b); return fromLab([p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t, p[2] + (q[2] - p[2]) * t]); }
function deltaE(a, b) { var p = toLab(a), q = toLab(b); return Math.hypot(p[0] - q[0], p[1] - q[1], p[2] - q[2]); }
function luminance(c) { var p = rgb(c); return 0.2126 * lin(p[0]) + 0.7152 * lin(p[1]) + 0.0722 * lin(p[2]); }
function contrast(a, b) { var x = luminance(a), y = luminance(b); return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05); }
function scaled(p, f) { return [Math.min(255, Math.max(0, Math.round(p[0] * f))), Math.min(255, Math.max(0, Math.round(p[1] * f))), Math.min(255, Math.max(0, Math.round(p[2] * f)))]; }

// Four-tone foils (shadow, base, highlight, glint) and other material ramps.
var TONES = {
    gold: ["#CC8730", "#F5AE39", "#FFDE8D", "#FFF6D1"],
    silver: ["#9AA0A7", "#B9BEC4", "#DDE1E5", "#F6F8FA"],
    pink: ["#C2557E", "#FA86B6", "#FFC0D9", "#FFEAF3"],
    green: ["#2C9A51", "#56D57B", "#A3EDB6", "#E2FBE8"],
    copper: ["#B16C4C", "#C57951", "#DC9A6C", "#ECC19C"],
    patina: ["#69BDAF", "#75CABB", "#82D7C8"],
    brass: ["#5E4019", "#9A6E2E", "#CFA552", "#F1D995"]
};
var RAMP = {};
function resetRamps() { RAMP = {}; for (var k in TONES) RAMP[k] = TONES[k].map(rgb); }
resetRamps();
// The skin's ramps image: one row per material (rows), `lengths` tones from the left.
function setRamps(rgba, w, rows, lengths) {
    resetRamps();
    for (var y = 0; y < rows.length; y++) {
        var n = Math.min(w, (lengths && lengths[y]) || w), list = [];
        for (var x = 0; x < n; x++) { var i = (y * w + x) * 4; list.push([rgba[i], rgba[i + 1], rgba[i + 2]]); }
        RAMP[rows[y]] = list;
    }
}
function ramp(name) { return RAMP[name] || RAMP.gold; }
// Continuous lookup along a ramp (loupe brass): v in [0, n-1].
function rampAt(P, v) {
    v = Math.max(0, Math.min(P.length - 1, v));
    var k = Math.min(P.length - 2, Math.floor(v)), f = v - k;
    return [Math.round(P[k][0] + (P[k + 1][0] - P[k][0]) * f), Math.round(P[k][1] + (P[k + 1][1] - P[k][1]) * f), Math.round(P[k][2] + (P[k + 1][2] - P[k][2]) * f)];
}

// ── Colour vision (DESIGN-SYSTEM.md §3.9a) ─────────────────────────────────
// Machado, Oliveira & Fernandes (2009), severity 1.0, applied in linear RGB.
var CVD = {
    protan: [[0.152286, 1.052583, -0.204868], [0.114503, 0.786281, 0.099216], [-0.003882, -0.048116, 1.051998]],
    deutan: [[0.367322, 0.860646, -0.227968], [0.280085, 0.672501, 0.047413], [-0.011820, 0.042940, 0.968881]],
    tritan: [[1.255528, -0.076749, -0.178779], [-0.078411, 0.930809, 0.147602], [0.004733, 0.691367, 0.303900]]
};
function simulate(c, type) {
    var M = CVD[type]; if (!M) return rgb(c);
    var p = rgb(c), l = [lin(p[0]), lin(p[1]), lin(p[2])];
    return [0, 1, 2].map(function (r) { return unlin(Math.max(0, Math.min(1, M[r][0] * l[0] + M[r][1] * l[1] + M[r][2] * l[2]))); });
}

