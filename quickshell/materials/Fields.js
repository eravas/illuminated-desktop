.pragma library
.import "Noise.js" as Noise
.import "Colour.js" as Colour
// Material fields from the skin (docs/SKINS.md, "materials"), installed by MaterialFields.qml:
// vellum texture, fray threshold, sheen, glint, patina. Painters read them through field(name);
// fieldsVersion() changes whenever they do. Until installed, tex() and frayAt() fall back to
// the procedural originals.

// ── Material fields (docs/SKINS.md, "materials") ──────────────────────────
// The skin's material images, decoded into channels: vellum (texture), fray (edge threshold),
// sheen (foil band profile along u), glint (glint noise), patina (spread and tone noise), ramps
// (tone ramps). Until they are installed (MaterialFields.qml), the procedural originals they
// were generated from stand in, so a first frame never fails.
var FIELDS = {}, version = 0;
function field(name) { return FIELDS[name] || null; }
function fieldsVersion() { return version; }
function setField(name, w, h, rgba, extra) {
    var n = w * h, r = new Float32Array(n), g = new Float32Array(n);
    for (var i = 0; i < n; i++) { r[i] = rgba[i * 4] / 255; g[i] = rgba[i * 4 + 1] / 255; }
    FIELDS[name] = {w: w, h: h, r: r, g: g, span: extra && extra.span};
    version++;
}
function clearFields() { FIELDS = {}; version++; Colour.resetRamps(); }
// A field's channel at (x, y), tiled.
function fieldAt(f, ch, x, y) {
    var xi = ((Math.floor(x) % f.w) + f.w) % f.w, yi = ((Math.floor(y) % f.h) + f.h) % f.h;
    return f[ch][yi * f.w + xi];
}
// Vellum texture in logical px: broad mottle, fine grain, horizontal fibres. Range ≈ ±0.5.
function tex(X, Y) {
    var f = FIELDS.vellum;
    if (f) return fieldAt(f, "r", X, Y) - 0.5;
    return 0.45 * Noise.vn(X / 42, Y / 42) + 0.25 * Noise.vn(X / 8, Y / 8) + 0.3 * Noise.vn(X / 80, Y / 2.2) - 0.5;
}
function frayAt(cx, cy) { var f = FIELDS.fray; return f ? fieldAt(f, "r", cx, cy) : Noise.ign(cx, cy); }
var TEXTURE_AMPLITUDE = {light: 0.07, dark: 0.12};

