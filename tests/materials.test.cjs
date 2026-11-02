// Numeric rules of the material painters (DESIGN-SYSTEM.md §3.5a, §3.9, §3.13).
const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const {load} = require('./visual/load.cjs');
const M = load('scripts/skin/Materials.js');
const R = load('quickshell/config/Reading.js');
const defaults = JSON.parse(fs.readFileSync('quickshell/config/defaults.json', 'utf8'));
const hex = c => '#' + c.map(v => v.toString(16).padStart(2, '0')).join('').toUpperCase();
const at = (px, W, x, y) => [px[(y * W + x) * 4], px[(y * W + x) * 4 + 1], px[(y * W + x) * 4 + 2]];
const same = (a, b) => a[0] === b[0] && a[1] === b[1] && a[2] === b[2];

function face(level, extra = {}) {
  const W = 248, H = 177, px = new Uint8ClampedArray(W * H * 4);
  M.paintCard(px, W, H, {D: 1, gc: 1, front: true, base: '#E3D4BC', edge: '#A6967B', edgeLine: false,
    art: {rgb: '#808080'}, ...extra, wash: {colour: '#FA86B6', level, axis: 'x', ...extra.wash}});
  return {px, W, H};
}

test('level mark: solid up to the level, dithering only outward past it', () => {
  const {px, W} = face(0.5), pink = M.rgb('#FA86B6'), card = M.rgb('#E3D4BC'), y = 3;   // a frame row
  for (let x = 12; x < 124; x++) assert(same(at(px, W, x, y), pink), `x=${x} inside the level`);
  let partial = 0;
  for (let x = 124; x < 124 + 12; x++) if (same(at(px, W, x, y), pink)) partial++;
  assert(partial > 0 && partial < 12, 'a dither fade beyond the mark');
  for (let x = 137; x < W - 12; x++) assert(same(at(px, W, x, y), card), `x=${x} past the fade`);
});

test('solid and line level marks', () => {
  const solid = face(0.5, {wash: {mark: 'solid'}}), pink = M.rgb('#FA86B6');
  assert(same(at(solid.px, solid.W, 123, 3), pink));
  assert(!same(at(solid.px, solid.W, 124, 3), pink));
  const line = face(0.5, {wash: {mark: 'line'}}), lc = at(line.px, line.W, 124, 3);
  assert(!same(lc, pink) && !same(lc, M.rgb('#E3D4BC')), 'a distinct 1 px line at the mark');
});

test('gold foil: only the four gold tones; at 100 % no cardstock and no burnish remains', () => {
  const gold = M.TONES.gold.map(M.rgb);
  for (const level of [0.3, 0.7, 1]) {
    const W = 248, H = 177, px = new Uint8ClampedArray(W * H * 4);
    M.paintCard(px, W, H, {D: 1, gc: 1, front: true, base: '#E3D4BC', edge: '#A6967B', edgeLine: false, wash: {foil: 'gold', level, axis: 'x'}});
    const limit = Math.floor(W * level) - 1;
    for (let x = 12; x < limit; x += 3) for (const y of [2, 5, H - 4]) {
      const c = at(px, W, x, y);
      if (px[(y * W + x) * 4 + 3] < 255) continue;   // rounded corner
      assert(gold.some(g => same(g, c)), `level ${level} (${x},${y}) ${hex(c)} not a gold tone`);
    }
  }
  assert.equal(M.burnAmount(1), 0);
  assert.equal(M.burnAmount(0.95), 1);
  assert.equal(M.sheenAmp(0), 0.25);
  assert.equal(M.sheenAmp(1), 1);
});

test('battery wash rises bottom-up and its dither goes upward', () => {
  const W = 154, H = 216, px = new Uint8ClampedArray(W * H * 4), green = M.rgb('#56D57B');
  M.paintCard(px, W, H, {D: 1, gc: 1, front: true, base: '#E3D4BC', edge: '#A6967B', edgeLine: false, wash: {colour: '#56D57B', level: 0.5, axis: 'y'}});
  for (let y = 109; y < H - 2; y++) assert(same(at(px, W, 3, y), green), `y=${y}`);
  for (let y = 2; y < 108 - 13; y++) assert(!same(at(px, W, 3, y), green), `y=${y} above the fade`);
});

test('rounded corners and the dog-ear cut are transparent', () => {
  const {px, W} = face(0.5, {cut: 18});
  assert.equal(px[3], 0);                              // top-left corner, outside the radius
  assert.equal(px[((2) * W + (W - 3)) * 4 + 3], 0);    // inside the cut corner
  assert.equal(px[((60) * W + (W - 3)) * 4 + 3], 255);
});

test('rail wash: solid for the first 20 %, gone after 95 %, side edges dithered', () => {
  const W = 46, H = 400, px = new Uint8ClampedArray(W * H * 4);
  M.paintWash(px, W, H, {x0: 0, y0: 0, w: W, h: H, tone: '#C1C2A3', horizontal: false, D: 1, gc: 1, amp: 0, mode: 'light'});
  for (let y = 12; y < 0.2 * H; y++) assert.equal(px[(y * W + 23) * 4 + 3], 255, `y=${y}`);
  for (let y = Math.ceil(0.95 * H); y < H; y++) assert.equal(px[(y * W + 23) * 4 + 3], 0, `y=${y}`);
  let edge = 0; for (let y = 20; y < 70; y++) edge += px[(y * W) * 4 + 3] ? 1 : 0;
  assert(edge > 0 && edge < 50, 'edge column partly covered');
});

test('wash tone runtime gate: mode ink passes 4.5:1 across the texture range', () => {
  for (const mode of ['light', 'dark']) for (const accent of ['#8A9F7B', '#1B3A8C', '#C02040', '#F2E14C']) {
    const p = defaults.palettes[mode], amp = M.TEXTURE_AMPLITUDE[mode];
    const r = M.washTone(p.paper, accent, p.ink, mode, 'medium');
    for (const f of [1 - amp, 1 + amp]) assert(M.contrast(M.scaled(r.tone, f), p.ink) >= 4.5, `${mode} ${accent}`);
  }
  const sage = M.washTone(defaults.palettes.light.paper, '#8A9F7B', defaults.palettes.light.ink, 'light', 'medium');
  assert.equal(sage.strength, 0.40);   // the medium tint itself passes with sage
  assert(M.deltaE(sage.tone, '#C1C2A3') < 0.01, hex(sage.tone));
});

const Sel = load('scripts/skin/painters/Selection.js');   // generator painters (the skin's images)
test('illuminated initials: no frame, edge dissolves through the dither; washes follow state', () => {
  const W = 32, px = new Uint8ClampedArray(W * W * 4);
  Sel.paintInitial(px, W, W, {kind: 'levels', level: 0.5, D: 1, gc: 1});
  let edge = 0; for (let x = 0; x < W; x++) edge += px[x * 4 + 3] ? 1 : 0;
  assert(edge < W, 'outer row partly transparent');
  const pink = M.TONES.pink.map(M.rgb), bottom = at(px, W, 16, 28), top = at(px, W, 16, 6);
  assert(pink.some(c => same(c, bottom)), 'pink below the level');
  assert(!pink.some(c => same(c, top)), 'gold above it');
});

test('loupe: brass band opaque, glass translucent, outside untouched', () => {
  const W = 54, H = 57, px = new Uint8ClampedArray(W * H * 4);
  Sel.paintLoupe(px, W, H, {band: 6, D: 1});
  assert.equal(px[((27) * W + 2) * 4 + 3], 255);               // band
  const glass = px[((27) * W + 27) * 4 + 3]; assert(glass > 0 && glass < 80, `glass alpha ${glass}`);
  assert.equal(px[(0 * W + 0) * 4 + 3], 0);
});

test('reading presets: explicit options win, presets are cumulative', () => {
  const d = R.resolve('default', {}), l = R.resolve('legibility', {}), a = R.resolve('accessibility', {});
  assert.equal(d.face, 'pirata'); assert.equal(l.face, 'germania'); assert.equal(a.face, 'sans');
  assert.equal(l.texture, 'reduced'); assert.equal(l.levelMark, 'line'); assert.equal(l.transitions, 'full');
  assert.equal(a.rotation, 'off'); assert.equal(a.dockAutoHide, 'never'); assert.equal(a.secondaryInk, 'high');
  assert.equal(R.resolve('accessibility', {face: 'germania'}).face, 'germania');
  assert.equal(R.resolve('legibility', {face: 'preset'}).face, 'germania');
  assert.equal(R.resolve('default', {face: 'bogus'}).face, 'pirata');
  assert(!R.isCustom('legibility', {face: 'germania'}));
  assert(R.isCustom('legibility', {rotation: 'off'}));
  // every option in defaults.toml is known, and vice versa
  assert.deepEqual(Object.keys(defaults.reading.options).sort(), [...Object.keys(R.OPTIONS)].sort());
});

test('workspace numerals: minuscule with terminal j, capitals, Arabic', () => {
  assert.deepEqual([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 14, 19].map(n => R.numeral(n, 'minuscule')),
    ['j', 'ij', 'iij', 'iv', 'v', 'vj', 'vij', 'viij', 'ix', 'x', 'xj', 'xiv', 'xix']);
  assert.equal(R.numeral(8, 'capital'), 'VIII');
  assert.equal(R.numeral(8, 'arabic'), '8');
  assert.equal(R.numeral(-3, 'minuscule'), '');
});

test('colour vision: simulations run; pairs below the gate are reported (advisory)', () => {
  const s = defaults.semantic, light = defaults.palettes.light;
  const pairs = [['volume vs muted', s.volume, s.volumeMuted], ['canary vs light cardstock', s.power, light.cardstock],
    ['patina vs light cardstock', s.verdigris, light.cardstock], ['copper vs critical', s.copper, s.critical]];
  const report = [];
  for (const type of ['protan', 'deutan', 'tritan']) for (const [name, a, b] of pairs) {
    const e = M.deltaE(M.simulate(a, type), M.simulate(b, type));
    if (e < 0.08) report.push(`${type}: ${name} ΔE ${e.toFixed(3)}`);
  }
  assert(report.length > 0, 'the known failures (§3.9a) are still visible to the check');
  assert.deepEqual([...M.simulate('#808080', 'deutan')].map(v => Math.abs(v - 128) <= 2), [true, true, true]);
});


test('selection images: the glass mask is the loupe\'s inner circle; ring and loupe per mode', () => {
  const fs = require('node:fs'), skin = JSON.parse(fs.readFileSync('quickshell/skins/default/skin.json', 'utf8'));
  for (const id of ['rail', 'dock']) {
    const l = skin.loupes[id];
    for (const f of [l.light, l.dark, l.glass, l.ring.light, l.ring.dark]) assert(fs.existsSync('quickshell/skins/default/' + f), f);
    assert.equal(l.size[1], l.size[0] + 3, 'three rows for the contact shadow');
  }
  assert(fs.existsSync('quickshell/skins/default/' + skin.initial));
});
