#!/usr/bin/env node
// Builds the default skin's material images (quickshell/skins/default/materials/ and
// materials.json): the vellum texture, the fray threshold, the foil sheen profile and glints,
// the patina noise and the tone ramps. The shell reads these images; the generators here are
// the old procedural ones, made tileable. Re-run, then build-default.cjs (which merges
// materials.json into skin.json).
//   node scripts/skin/build-materials.cjs
const path = require('node:path');
const fs = require('node:fs');
const zlib = require('node:zlib');
const {load} = require('../../tests/visual/load.cjs');
const root = path.resolve(__dirname, '../..');
const out = path.join(root, 'quickshell/skins/default');
const M = load(path.join(root, 'scripts/skin/Materials.js'));
const Sel = load(path.join(__dirname, 'painters/Selection.js'));

// A minimal PNG writer (RGBA, 8-bit), so this needs no browser.
function png(w, h, rgba) {
  const raw = Buffer.alloc((w * 4 + 1) * h);
  for (let y = 0; y < h; y++) { raw[y * (w * 4 + 1)] = 0; Buffer.from(rgba.buffer, rgba.byteOffset + y * w * 4, w * 4).copy(raw, y * (w * 4 + 1) + 1); }
  const crcTable = Array.from({length: 256}, (_, n) => { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xEDB88320 ^ (c >>> 1) : c >>> 1; return c >>> 0; });
  const crc = b => { let c = 0xFFFFFFFF; for (const x of b) c = crcTable[(c ^ x) & 255] ^ (c >>> 8); return (c ^ 0xFFFFFFFF) >>> 0; };
  const chunk = (type, data) => { const t = Buffer.from(type), len = Buffer.alloc(4), c = Buffer.alloc(4); len.writeUInt32BE(data.length); c.writeUInt32BE(crc(Buffer.concat([t, data]))); return Buffer.concat([len, t, data, c]); };
  const ihdr = Buffer.alloc(13); ihdr.writeUInt32BE(w, 0); ihdr.writeUInt32BE(h, 4); ihdr[8] = 8; ihdr[9] = 6;
  return Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk('IHDR', ihdr), chunk('IDAT', zlib.deflateSync(raw, {level: 9})), chunk('IEND', Buffer.alloc(0))]);
}
function write(name, w, h, fill) {
  const px = new Uint8Array(w * h * 4);
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) { const v = fill(x, y), i = (y * w + x) * 4;
    px[i] = clamp(v[0]); px[i + 1] = clamp(v[1] === undefined ? v[0] : v[1]); px[i + 2] = clamp(v[2] === undefined ? v[0] : v[2]); px[i + 3] = 255; }
  fs.mkdirSync(path.join(out, 'materials'), {recursive: true});
  fs.writeFileSync(path.join(out, 'materials', name), png(w, h, px));
}
const clamp = v => Math.max(0, Math.min(255, Math.round(v)));
// Value noise on a torus (period cells per axis), so every field tiles without a seam.
function vnA(x, y, cx, cy, px, py, seed) {
  const gx = Math.floor(x / cx), gy = Math.floor(y / cy), fx = x / cx - gx, fy = y / cy - gy;
  const h = (a, b) => M.h2(((a % px) + px) % px + seed * 977, ((b % py) + py) % py + seed * 613);
  const s = t => t * t * (3 - 2 * t), u = s(fx), v = s(fy), A = h(gx, gy), B = h(gx + 1, gy), C = h(gx, gy + 1), D = h(gx + 1, gy + 1);
  return A + (B - A) * u + (C - A) * v + (A - B - C + D) * u * v;
}
const vnT = (x, y, cell, period, seed) => vnA(x, y, cell, cell, period, period, seed);

// Vellum texture (Materials.tex: broad mottle, fine grain, horizontal fibres), 1 texel per
// logical px, 1024 tile. R = texture + 0.5.
const T = 1024;
write('vellum.png', T, T, (x, y) => {
  const t = 0.45 * vnT(x, y, T / 24, 24, 1) + 0.25 * vnT(x, y, T / 128, 128, 2) + 0.3 * vnA(x, y, T / 13, T / 465, 13, 465, 3) - 0.5;
  return [(t + 0.5) * 255];
});
// Fray threshold per grain cell (the edge's interleaved-gradient noise), 64 tile.
write('fray.png', 64, 64, (x, y) => [M.ign(x, y) * 255]);
// Foil sheen profile along u = 0.75·x/w + 0.45·y/h, u in [0, 1.2] over 256 texels:
// R = band strength / 2, G = glint band (255 where glints may appear).
write('sheen.png', 256, 1, (x) => {
  const u = x / 255 * 1.2, b1 = Math.exp(-Math.pow((u - 0.42) / 0.09, 2)), b2 = Math.exp(-Math.pow((u - 0.78) / 0.04, 2)), b3 = Math.exp(-Math.pow((u - 1.06) / 0.075, 2));
  return [(1.5 * b1 + 0.7 * b2 + 1.2 * b3) / 2 * 255, b1 > 0.55 || b3 > 0.6 ? 255 : 0, 0];
});
// Glint noise per grain cell, 64 tile.
write('glint.png', 64, 64, (x, y) => [M.ign(x * 3.1, y * 1.7) * 255]);
// Patina noise in logical px, 512 tile: R = the spread noise (two scales), G = the tone noise.
write('patina.png', 512, 512, (x, y) => [(vnT(x, y, 512 / 20, 20, 7) * 0.6 + vnT(x, y, 512 / 46, 46, 13) * 0.4) * 255, vnT(x, y, 512 / 23, 23, 29) * 255]);
// Tone ramps: one row per material, tones left to right.
const rows = ['gold', 'silver', 'pink', 'green', 'copper', 'patina', 'brass'];
write('ramps.png', 4, rows.length, (x, y) => { const t = M.TONES[rows[y]]; return M.rgb(t[Math.min(x, t.length - 1)]); });

// Selection: the rail and dock loupes (brass, glass vignette and highlight, contact shadow
// below) per mode, their glass masks (white = where the magnified content shows), and the
// fallback ring (Accessibility: brass with a solid inner ring in mode ink, no glass). 4×.
const Q = 4, defaultsJson = JSON.parse(fs.readFileSync(path.join(root, 'quickshell/config/defaults.json'), 'utf8'));
function canvasWrite(name, W, H, paint) {
  const px = new Uint8ClampedArray(W * H * 4); paint(px);
  fs.writeFileSync(path.join(out, 'materials', name), png(W, H, px));
}
const loupes = {};
for (const [id, diameter] of [['rail', 54], ['dock', Math.round(30 * 1.12 + 18)]]) {
  const W = diameter * Q, H = (diameter + 3) * Q, band = 6;
  for (const mode of ['light', 'dark']) canvasWrite(`loupe-${id}-${mode}.png`, W, H, px => Sel.paintLoupe(px, W, H, {band, dark: mode === 'dark', D: Q}));
  canvasWrite(`loupe-${id}-glass.png`, W, H, px => { const R = W / 2, r = R - band * Q; for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    const d = Math.hypot(x + 0.5 - R, y + 0.5 - R), a = Math.max(0, Math.min(1, r - d + 0.5)), i = (y * W + x) * 4; px[i] = px[i + 1] = px[i + 2] = 255; px[i + 3] = Math.round(a * 255); } });
  for (const mode of ['light', 'dark']) canvasWrite(`ring-${id}-${mode}.png`, W, H, px => Sel.paintRing(px, W, W, {band, D: Q, ink: defaultsJson.palettes[mode].ink}));
  loupes[id] = {size: [diameter, diameter + 3], light: `materials/loupe-${id}-light.png`, dark: `materials/loupe-${id}-dark.png`, glass: `materials/loupe-${id}-glass.png`,
                ring: {light: `materials/ring-${id}-light.png`, dark: `materials/ring-${id}-dark.png`}};
}
fs.writeFileSync(path.join(out, 'loupes.json'), JSON.stringify(loupes, null, 2) + '\n');
// The illuminated-initial ground (fallback hand icon): plain gold foil, 32 px at 4×.
canvasWrite('initial.png', 32 * Q, 32 * Q, px => Sel.paintInitial(px, 32 * Q, 32 * Q, {kind: 'plain', D: Q, gc: Q}));

const materials = {
  vellum: {image: 'materials/vellum.png', size: [T, T]},
  fray: {image: 'materials/fray.png', size: [64, 64]},
  sheen: {image: 'materials/sheen.png', size: [256, 1], span: 1.2},
  glint: {image: 'materials/glint.png', size: [64, 64]},
  patina: {image: 'materials/patina.png', size: [512, 512]},
  ramps: {image: 'materials/ramps.png', size: [4, rows.length], rows, lengths: rows.map(r => M.TONES[r].length)}
};
fs.writeFileSync(path.join(out, 'materials.json'), JSON.stringify(materials, null, 2) + '\n');
console.log('wrote material images and materials.json to', out);
