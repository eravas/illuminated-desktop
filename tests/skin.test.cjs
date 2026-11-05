// Skins: the pure half (quickshell/skin/Skin.js, docs/SKINS.md).
const {test} = require('node:test');
const assert = require('node:assert/strict');
const {load} = require('./visual/load.cjs');
const S = load('quickshell/skin/Skin.js');
const j = v => JSON.stringify(v);

test('merge: objects merge, arrays replace, null removes', () => {
  const base = {elements: {a: {size: [1, 2], image: 'a.png'}, b: {size: [1, 1]}}, rail: {items: [1, 2]}};
  const out = S.merge(base, {elements: {a: {image: 'mine.png'}, b: null}, rail: {items: [3]}});
  assert.equal(j(out), j({elements: {a: {size: [1, 2], image: 'mine.png'}}, rail: {items: [3]}}));
  assert.equal(base.elements.a.image, 'a.png', 'the base is not changed');
});

test('images: files, sheet cells, grid runs and lists', () => {
  const m = {sheets: {objs: {file: 'objects.png', columns: 4}},
    images: {nib: 'rail/nib.png', vial: {sheet: 'objs', rect: [0, 0, 10, 20]}, run: {sheet: 'objs', grid: [10, 20], start: 2, count: 4},
             both: ['nib', 'vial'], alias: 'nib'}};
  assert.equal(j(S.image(m, 'nib')), j({file: 'rail/nib.png', rect: null}));
  assert.equal(j(S.image(m, 'vial').rect), j([0, 0, 10, 20]));
  assert.equal(j(S.frames(m, 'run').map(f => f.rect)), j([[20, 0, 10, 20], [30, 0, 10, 20], [0, 20, 10, 20], [10, 20, 10, 20]]));
  assert.equal(S.frames(m, 'both').length, 2);
  assert.equal(S.image(m, 'alias').file, 'rail/nib.png');
  assert.equal(S.image(m, 'direct.png').file, 'direct.png', 'a bare file name works');
  assert.equal(S.image(m, 'missing'), null);
  const el = {image: 'nib', states: [{when: {source: 'x'}, frames: {source: 'v', images: 'run'}}], regions: [{id: 'r', image: 'vial', hit: {mask: 'both'}}]};
  assert.equal(j(S.files(m, el).sort()), j(['objects.png', 'rail/nib.png']));
});

test('conditions and looks: the first matching state wins', () => {
  const st = {'battery.state': 'chg', 'battery.level': 0.42, unread: 0};
  assert(S.test({source: 'battery.state', eq: 'chg'}, st));
  assert(S.test({all: [{source: 'battery.level', gt: 0.4}, {not: {source: 'unread', truthy: true}}]}, st));
  assert(!S.test({any: [{source: 'battery.level', lt: 0.1}, {source: 'battery.state', in: ['held']}]}, st));
  const el = {image: 'plain', frames: null, states: [{when: {source: 'battery.state', eq: 'held'}, image: 'held'},
                                                      {when: {source: 'battery.state', eq: 'chg'}, frames: {source: 'battery.level', images: 'charging'}}]};
  const l = S.look(el, st);
  assert.equal(l.image, null); assert.equal(l.frames.images, 'charging');
  assert.equal(S.look(el, {'battery.state': 'dis'}).image, 'plain');
  assert.equal(S.frameIndex({source: 'battery.level'}, 11, st), 4);
  assert.equal(S.frameIndex({source: 'v', min: 0, max: 4}, 5, {v: 3}), 3);
  assert.equal(j(S.sources({states: el.states, frames: {source: 'volume'}, animations: {'change:unread': {}}}).sort()), j(['battery.level', 'battery.state', 'unread', 'volume']));
});

test('templates', () => {
  assert.equal(S.format('Sound {{volume|percent}} · {{unread}} {{unread|plural:letter}}', {volume: 0.62, unread: 2}), 'Sound 62% · 2 letters');
  assert.equal(S.format('{{missing}}x', {}), 'x');
});

test('animations: frames by mode, tweens by time', () => {
  assert.equal(S.frameAt({fps: 10}, 3, 150), 1);
  assert.equal(S.frameAt({fps: 10}, 3, 350), -1, 'once ends');
  assert.equal(S.frameAt({fps: 10, mode: 'hold'}, 3, 950), 2);
  assert.equal(S.frameAt({fps: 10, mode: 'loop'}, 3, 450), 1);
  assert.equal(j([0, 100, 200, 300, 400, 500].map(t => S.frameAt({fps: 10, mode: 'pingpong'}, 3, t))), j([0, 1, 2, 1, 0, 1]));
  const half = S.tweenAt({}, {tween: {x: -4, scale: 1.2}, duration: 100, easing: 'linear'}, 50);
  assert.equal(half.x, -2); assert(Math.abs(half.scale - 1.1) < 1e-9); assert.equal(half.opacity, 1);
  assert.equal(S.tweenAt({x: -4}, {tween: {}, duration: 0}, 0).x, 0, 'an empty tween returns to rest');
});

test('active areas: shapes, regions on top, live filter, alpha lookups', () => {
  assert(S.inShape({polygon: [[0, 0], [10, 0], [0, 10]]}, 2, 2));
  assert(!S.inShape({polygon: [[0, 0], [10, 0], [0, 10]]}, 8, 8));
  assert(S.inShape({circle: [5, 5, 2]}, 6, 6));
  const el = {hit: {rect: [0, 0, 20, 20]}, regions: [{id: 'clip', hit: {circle: [5, 5, 3]}}, {id: 'tray', hit: [{rect: [4, 4, 4, 4]}]}]};
  const none = () => false;
  assert.equal(S.hit(el, 5, 5, none), 'tray', 'the last region is on top');
  assert.equal(S.hit(el, 3, 5, none), 'clip');
  assert.equal(S.hit(el, 5, 5, none, r => r.id !== 'tray'), 'clip', 'a disabled region passes through');
  assert.equal(S.hit(el, 15, 15, none), '#', 'the element itself');
  assert.equal(S.hit(el, 25, 25, none), '');
  const masked = {regions: [{id: 'stamp', hit: {mask: 'stamp-hit'}}]};
  assert.equal(S.hit(masked, 1, 1, (k, x, y, r) => k === 'mask:stamp-hit' && r === 'stamp'), 'stamp');
  assert.equal(S.hit({}, 1, 1, (k) => k === 'alpha'), '#', 'by default the drawn pixels are the element');
});

test('actions and validation', () => {
  assert.equal(j(S.parseAction('deal:levels')), j({name: 'deal', arg: 'levels'}));
  assert.equal(j(S.parseAction('command:screenshot')), j({name: 'command', arg: 'screenshot'}));
  assert.equal(S.parseAction('rm -rf /'), null);
  const errs = S.check({units: 'in', elements: {a: {size: [1], image: 'nope', triggers: {click: 'explode', hover: 'launcher'}}},
                        rail: {items: [{element: 'b'}]}, cards: {c: {}}});
  for (const want of ['units', 'elements.a.size', 'elements.a.image', 'triggers.click', 'triggers.hover', 'rail.items[0]', 'cards.c.face'])
    assert(errs.some(e => e.includes(want)), `reports ${want}: ${errs.join(' | ')}`);
  assert.equal(S.check({elements: {ok: {size: [1, 1], image: 'x.png', triggers: {click: 'launcher'}}}}).length, 0);
});

test('the default skin is valid, and every image it names exists', () => {
  const fs = require('node:fs'), path = require('node:path'), dir = 'quickshell/skins/default';
  const m = JSON.parse(fs.readFileSync(dir + '/skin.json', 'utf8'));
  assert.equal(S.check(m).join(' | '), '');
  const files = new Set();
  for (const id in m.elements) S.files(m, m.elements[id]).forEach(f => files.add(f));
  for (const k in m.devices) { files.add(m.devices[k].image); files.add(m.devices[k].envelope); }
  files.add(m.media.seal); files.add(m.media.sealCracked);
  for (const f of files) assert(fs.existsSync(path.join(dir, f)), 'missing ' + f);
  for (const it of m.rail.items) if (it.element || it.foot) assert(m.elements[it.element || it.foot], 'rail item ' + JSON.stringify(it));
  for (const id in m.elements) for (const t of Object.values(m.elements[id].triggers || {})) assert(S.parseAction(t), id + ' ' + t);
  const D = load('quickshell/materials/DeviceGeometry.js');
  for (const k of D.KINDS) assert(m.devices[k], 'device art for ' + k);
});

test('compose: ink to the level, bands and markers by state, regions over the base', () => {
  const C = load('quickshell/skin/Compose.js');
  const g = C.geometry([10, 1], 1, 0, 1);           // 10 × 1 px, no margin
  const solid = (c) => { const p = new Uint8ClampedArray(g.W * g.H * 4); for (let i = 0; i < p.length; i += 4) { p[i] = c[0]; p[i + 1] = c[1]; p[i + 2] = c[2]; p[i + 3] = 255; } return p; };
  const layers = {'glass.png': solid([255, 255, 255]), 'mask.png': solid([255, 255, 255]), 'dot.png': solid([1, 2, 3])};
  const m = {images: {glass: 'glass.png', mask: 'mask.png', dot: 'dot.png'}};
  const look = {image: 'glass', ink: {mask: 'mask', from: [0, 0.5], to: [9, 0.5], source: 'v'}, markers: []};
  const px = C.compose({manifest: m, g, look, state: {v: 0.5}, layer: ref => layers[ref.file], regions: []});
  assert(px[0] < 120 && px[4 * 4] < 120, 'inked to the level'); assert.equal(px[7 * 4], 255, 'clear past it');
  const withRegion = C.compose({manifest: m, g, look: {image: 'glass'}, state: {}, layer: ref => layers[ref.file], regions: [{look: {image: 'dot'}, rect: null}]});
  assert.equal(withRegion[0], 1, 'a region is drawn over the base');
  const f = C.frameOf({images: {run: ['a.png', 'b.png', 'c.png']}}, {frames: {source: 'n', min: 0, max: 2, images: 'run'}}, {n: 2});
  assert.equal(f.file, 'c.png');
  const big = C.geometry([4, 2], 3, 6, 2);
  assert.equal(big.W, Math.round((12 + 12) * 2)); assert.equal(JSON.stringify(C.toDevice(big, [1, 1])), JSON.stringify([18, 18]));
});

test('devices: a skin may add a kind sized from its own dimensions', () => {
  const D = load('quickshell/materials/DeviceGeometry.js');
  assert(D.registerArt('tome', {image: 'd.png', size: [120, 80], like: 'ereader'}) && D.device('tome').fromBottom && D.device('tome').L === 120);
  assert(!D.registerArt('bad', {image: 'd.png'}) && D.device('bad') === D.DEVICES.ssd, 'invalid geometry falls back');
  const A = load('quickshell/materials/DeviceArt.js'); A.setImages({usb: {device: 'u.png', envelope: 'e.png'}}, {seal: 's.png', cracked: 'c.png'});
  assert.equal(A.imageUrls('usb').join(), 'u.png,e.png,s.png,c.png');
});

test('doctor: check.cjs applies Skin.check to the merged skin', () => {
  const {spawnSync} = require('node:child_process'), os = require('node:os'), fs = require('node:fs'), path = require('node:path');
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'skin-')), f = path.join(dir, 'skin.json');
  fs.writeFileSync(f, '{"elements":{"x":{"size":"bad"}}}');
  const r = spawnSync('node', ['scripts/skin/check.cjs', 'quickshell', f], {encoding: 'utf8'});
  assert.equal(r.status, 1); assert.match(r.stdout, /elements\.x\.size/);
  assert.equal(spawnSync('node', ['scripts/skin/check.cjs', 'quickshell', 'quickshell/skins/example/skin.json']).status, 0);
});

