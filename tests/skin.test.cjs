// Skins (docs/SKINS.md). The QML skin is covered at runtime (tests/runtime/skin.py); these
// cover what stays pure: device art a skin adds, and the baked frame sheets the QML reads.
const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {load} = require('./visual/load.cjs');

test('devices: a skin may add a kind sized from its own dimensions', () => {
  const D = load('quickshell/materials/DeviceGeometry.js');
  assert(D.registerArt('tome', {image: 'd.png', size: [120, 80], like: 'ereader'}) && D.device('tome').fromBottom && D.device('tome').L === 120);
  assert(!D.registerArt('bad', {image: 'd.png'}) && D.device('bad') === D.DEVICES.ssd, 'invalid geometry falls back');
  const A = load('quickshell/materials/DeviceArt.js'); A.setImages({usb: {device: 'u.png', envelope: 'e.png'}}, {seal: 's.png', cracked: 'c.png'});
  assert.equal(A.imageUrls('usb').join(), 'u.png,e.png,s.png,c.png');
});

// FrameImage computes a cell as round((size × 1920/531 (mm) or 1 (px) + 2 × shadowMargin) × D):
// every sheet a skin QML file names must exist at 1× and 2×, with whole cells of that size.
function pngSize(file) { const b = fs.readFileSync(file); return [b.readUInt32BE(16), b.readUInt32BE(20)]; }
test('baked sheets exist at 1x and 2x with the cells FrameImage expects', () => {
  const cells = {   // name: [size, units, shadowMargin, frames]
    'default/elements/tray': [[24, 24], 'px', 0, 2], 'default/elements/nib': [[17, 10], 'mm', 6, 1],
    'default/elements/vial': [[17, 9], 'mm', 6, 25], 'default/elements/antenna': [[17, 12], 'mm', 6, 12],
    'default/elements/converter': [[17, 28], 'mm', 6, 75], 'default/elements/matchbox': [[17, 13], 'mm', 6, 1],
    'default/elements/paper': [[18, 22], 'mm', 6, 14], 'example/elements/seal': [[26, 26], 'px', 6, 1],
    'example/elements/quiet': [[30, 30], 'px', 6, 2], 'example/elements/paper': [[18, 22], 'mm', 6, 7],
    'example/elements/clip': [[12, 12], 'mm', 6, 5]};
  for (const [name, [size, units, margin, frames]] of Object.entries(cells)) for (const D of [1, 2]) {
    const file = path.join('quickshell/skins', name + (D === 2 ? '-2x' : '') + '.png'), k = units === 'px' ? 1 : 1920 / 531;
    const [w, h] = pngSize(file), cw = Math.round((size[0] * k + 2 * margin) * D), ch = Math.round((size[1] * k + 2 * margin) * D);
    assert.equal(w, cw * frames, `${file}: ${frames} cells of ${cw}`); assert.equal(h, ch, file);
  }
});
