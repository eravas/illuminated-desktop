#!/usr/bin/env node
// Builds the default skin (quickshell/skins/default/: skin.json and its images) from the
// painters in scripts/skin/painters/. The shell itself never draws these objects: it loads the
// images, composites, dithers and shadows them. Re-run after changing a painter.
//   node scripts/skin/build-default.cjs [outdir]
// Developer tool: needs Playwright's Chromium.
const path = require('node:path');
const fs = require('node:fs');
const {wrapped} = require('../../tests/visual/load.cjs');
const root = path.resolve(__dirname, '../..');
const out = path.resolve(process.argv[2] || path.join(root, 'quickshell/skins/default'));
const defaults = JSON.parse(fs.readFileSync(path.join(root, 'quickshell/config/defaults.json'), 'utf8'));
const INK = {light: defaults.palettes.light.ink, dark: defaults.palettes.dark.ink};

const shared = new Map();   // one copy of every module, as in QML
const lib = [
  fs.readFileSync(path.join(root, 'tests/visual/qml-context2d.js'), 'utf8'),
  wrapped(path.join(__dirname, 'painters/RailObjects.js'), 'Rail', shared),
  wrapped(path.join(__dirname, 'painters/DeviceArt.js'), 'Dev', shared),
].join('\n');

const page = `<!doctype html><body><script>${lib}
const S = 10, E = 16, INK = ${JSON.stringify(INK)};      // px per mm; the rail's working end in mm
const files = {};
function cv(w, h) { const c = document.createElement('canvas'); c.width = Math.round(w); c.height = Math.round(h); return c; }
function save(p, c) { files[p] = c.toDataURL('image/png'); }
function hand(kind, d, state, ink) { const c = cv((E + 1) * S, d * S), x = qmlContext(c); x.translate(0, d * S / 2); Rail.draw(x, kind, S, E * S, state, ink || INK.light); return c; }
function diff(a, b, keep) {   // pixels where a and b differ: white (a mask), or b's colour (keep)
  const W = a.width, H = a.height, A = a.getContext('2d').getImageData(0, 0, W, H).data, B = b.getContext('2d').getImageData(0, 0, W, H).data;
  const m = cv(W, H), mc = m.getContext('2d'), img = mc.createImageData(W, H);
  for (let i = 0; i < A.length; i += 4) {
    const d = Math.abs(A[i] - B[i]) + Math.abs(A[i + 1] - B[i + 1]) + Math.abs(A[i + 2] - B[i + 2]) + Math.abs(A[i + 3] - B[i + 3]);
    if (d > 24) { if (keep) { img.data[i] = B[i]; img.data[i + 1] = B[i + 1]; img.data[i + 2] = B[i + 2]; } else img.data[i] = img.data[i + 1] = img.data[i + 2] = 255; img.data[i + 3] = 255; }
  }
  mc.putImageData(img, 0, 0); return m;
}
function sheet(cells, cols) {   // cells: canvases of one size → one sheet canvas
  const w = cells[0].width, h = cells[0].height, rows = Math.ceil(cells.length / cols), s = cv(w * cols, h * rows), x = s.getContext('2d');
  cells.forEach((c, i) => x.drawImage(c, (i % cols) * w, Math.floor(i / cols) * h)); return s;
}
window.build = function () {
  const K = Rail, geo = {};
  // Nib, matchbox.
  save('rail/nib.png', hand('launcher', 10, {})); geo.nib = 10;
  save('rail/matchbox.png', hand('power', 13, {})); geo.matchbox = 13;
  // Vial: empty glass and where the ink goes.
  { const empty = hand('levels', 9, {level: 0}); save('rail/vial.png', empty); save('rail/vial-ink.png', diff(empty, hand('levels', 9, {level: 1}))); geo.vial = 9; }
  // Converter: bare, and where the ink goes; its axis for the fill.
  { const sp = K.converterSpan(S, E * S), d = Math.ceil((sp.top + sp.drop) / S) + 1;
    const empty = hand('battery', d, {level: 0, bare: true}); save('rail/converter.png', empty); save('rail/converter-ink.png', diff(empty, hand('battery', d, {level: 1, bare: true})));
    const t = K.CONVERTER_ANGLE, y0 = d * S / 2 - (sp.top + sp.drop) / 2 + sp.top, dir = [-Math.cos(t), Math.sin(t)];
    const at = u => [+((sp.xm + dir[0] * u) / S).toFixed(2), +((y0 + dir[1] * u) / S).toFixed(2)];
    geo.converter = {d, from: at(K.CONVERTER_RESERVOIR[0] * S), to: at((K.CONVERTER_RESERVOIR[1] - 1.8) * S), mouth: at(1)}; }
  // Antenna: a sheet, one row per mode ink: stages 0–4, then connecting.
  { const cells = [];
    for (const mode of ['light', 'dark']) { for (let s = 0; s <= 4; s++) cells.push(hand('connections', 12, {stage: s}, INK[mode])); cells.push(hand('connections', 12, {stage: 0, connecting: true}, INK[mode])); }
    save('rail/antenna-sheet.png', sheet(cells, 6)); geo.antenna = {d: 12, w: cells[0].width, h: cells[0].height}; }
  // Paper: the sheet, the clip, handwriting for 0–6 unread (a sheet of frames).
  { const Wm = 18, Hm = 22, c = cv(Wm * S, Hm * S), x = qmlContext(c);
    K.paper(x, Wm * S, Hm * S, S, {unread: 0}, INK.light, false); save('rail/paper.png', c);
    const g = K.paperGeometry(Wm * S, Hm * S, S, true), cs = 12, clip = cv(cs * S, cs * S), cx = qmlContext(clip);
    K.paperclip(cx, cs * S / 2, cs * S / 2, Math.atan2(-g.B[1], -g.B[0]), S); save('rail/paperclip.png', clip);
    const frames = [];
    for (let n = 0; n <= 6; n++) { const w = cv(Wm * S, Hm * S), wx = qmlContext(w); K.paper(wx, Wm * S, Hm * S, S, {unread: n}, INK.light, false); frames.push(n ? diff(c, w, true) : cv(Wm * S, Hm * S)); }
    save('rail/writing-sheet.png', sheet(frames, 7));
    geo.paper = {w: Wm, h: Hm, clip: [+(g.clip[0] / S - cs / 2).toFixed(2), +(g.clip[1] / S - cs / 2).toFixed(2), cs, cs]}; }
  // Tray marks, one per mode ink.
  for (const mode of ['light', 'dark']) { const c = cv(96, 96), x = qmlContext(c); K.trayMark(x, 96, INK[mode]); save('rail/tray-' + mode + '.png', c); }
  // Removable media: each device in its local rect (leading end right), its envelope, the seal.
  const dev = {};
  for (const kind of Dev.KINDS) {
    const dv = Dev.DEVICES[kind], u = 6 * dv.real / dv.drawn;   // 6 px/mm: the sharpest life-size output (15.6″ 1080p) is 5.6
    const r = dv.disc ? [-dv.R, -dv.R, 2 * dv.R, 2 * dv.R] : [-dv.L, -dv.drawn / 2, dv.L, dv.drawn], er = [r[0] - 2, r[1] - 2, r[2] + 4, r[3] + 4];
    const c = cv(r[2] * u, r[3] * u), x = qmlContext(c); x.scale(u, u); x.translate(-r[0], -r[1]); dv.draw(x); save('devices/' + kind + '.png', c);
    const e = cv(er[2] * u, er[3] * u), ex = qmlContext(e); ex.scale(u, u); ex.translate(-er[0], -er[1]); Dev.envelope(ex, dv); save('devices/' + kind + '-envelope.png', e);
    dev[kind] = {image: 'devices/' + kind + '.png', envelope: 'devices/' + kind + '-envelope.png'};
  }
  for (const cracked of [false, true]) { const c = cv(104, 104), x = qmlContext(c); x.scale(4, 4); Dev.seal(x, 13, 13, cracked); save(cracked ? 'devices/seal-cracked.png' : 'devices/seal.png', c); }
  // ── The example skin (quickshell/skins/example, docs/SKINS.md): images it adds. ──
  const ex = {};
  { const Wm = 18, Hm = 22, g = K.paperGeometry(Wm * S, Hm * S, S, true), cs = 12;
    const ts = 6, t = cv(ts * S, ts * S), tx = qmlContext(t); K.trayMark(tx, ts * S, '#26304A'); ex['rail/tray-stamp.png'] = t.toDataURL('image/png');
    const frames = [];
    for (const deg of [0, -8, 6, -3, 0]) { const c = cv(cs * S, cs * S), x = qmlContext(c); K.paperclip(x, cs * S / 2, cs * S / 2, Math.atan2(-g.B[1], -g.B[0]) + deg * Math.PI / 180, S); frames.push(c); }
    ex['rail/clip-wiggle.png'] = sheet(frames, 5).toDataURL('image/png'); }
  { // A card face: an inkwell vial on cardstock, 154 × 215.6 logical px at 4×.
    const w = 616, h = 862, c = cv(w, h), x = c.getContext('2d');
    x.fillStyle = '#E3D4BC'; x.beginPath(); x.roundRect(0, 0, w, h, 34); x.fill();
    x.fillStyle = '#C9DCE3'; x.beginPath(); x.roundRect(40, 40, w - 80, h * 0.81 - 40, 24); x.fill();
    const v = cv(17 * 30, 9 * 30), vx = qmlContext(v); vx.translate(0, 9 * 15); Rail.draw(vx, 'levels', 30, 16 * 30, {level: 0.7}, '#26372C');
    x.save(); x.translate(w / 2, h * 0.42); x.rotate(-Math.PI / 2); x.drawImage(v, -v.width / 2 - 40, -v.height / 2); x.restore();
    ex['cards/inkwell.png'] = c.toDataURL('image/png'); }
  return {files, geo, dev, ex};
};
</script></body>`;

function manifest(geo, dev) {
  const mode = m => ({source: 'mode', eq: m});
  const a = geo.antenna;
  return {
    name: 'Illuminated (default)',
    about: 'Generated by scripts/skin/build-default.cjs from scripts/skin/painters/. Copy what you want to change into ~/.config/illuminated/skin/ (docs/SKINS.md).',
    units: 'mm',
    inks: {'iron-gall': ['#151C30', '#24304F', '#3A4C78']},
    sheets: {
      antenna: {file: 'rail/antenna-sheet.png', columns: 6},
      writing: {file: 'rail/writing-sheet.png', columns: 7}
    },
    images: {
      nib: 'rail/nib.png', matchbox: 'rail/matchbox.png', vial: 'rail/vial.png', 'vial.ink': 'rail/vial-ink.png',
      converter: 'rail/converter.png', 'converter.ink': 'rail/converter-ink.png', paper: 'rail/paper.png', paperclip: 'rail/paperclip.png',
      'tray.light': 'rail/tray-light.png', 'tray.dark': 'rail/tray-dark.png',
      'antenna.light': {sheet: 'antenna', grid: [a.w, a.h], start: 0, count: 5}, 'antenna.light.connecting': {sheet: 'antenna', grid: [a.w, a.h], start: 5, count: 1},
      'antenna.dark': {sheet: 'antenna', grid: [a.w, a.h], start: 6, count: 5}, 'antenna.dark.connecting': {sheet: 'antenna', grid: [a.w, a.h], start: 11, count: 1},
      writing: {sheet: 'writing', grid: [geo.paper.w * 10, geo.paper.h * 10], start: 0, count: 7}
    },
    elements: {
      tray: {units: 'px', size: [24, 24], anchor: [12, 12], image: 'tray.light', states: [{when: mode('dark'), image: 'tray.dark'}],
             dither: false, shadow: false, hit: {rect: [-8, -4, 40, 32]}, triggers: {click: 'tray'}, tag: 'Tray'},
      nib: {size: [17, geo.nib], anchor: [16, geo.nib / 2], image: 'nib', triggers: {click: 'launcher'}, tag: 'Launcher'},
      vial: {size: [17, geo.vial], anchor: [16, geo.vial / 2], image: 'vial',
             ink: {mask: 'vial.ink', from: [8, geo.vial / 2 + 3.6], to: [8, geo.vial / 2 - 3.6], source: 'volume'},
             triggers: {click: 'deal:levels', scrollUp: 'volume:+5', scrollDown: 'volume:-5', middleClick: 'mute'}},
      antenna: {size: [17, a.d], anchor: [16, a.d / 2], frames: {source: 'network.stage', min: 0, max: 4, images: 'antenna.light'},
                states: [
                  {when: {all: [mode('dark'), {source: 'network.connecting', truthy: true}, {source: 'network.stage', eq: 0}]}, image: 'antenna.dark.connecting'},
                  {when: {all: [{source: 'network.connecting', truthy: true}, {source: 'network.stage', eq: 0}]}, image: 'antenna.light.connecting'},
                  {when: mode('dark'), frames: {source: 'network.stage', min: 0, max: 4, images: 'antenna.dark'}}],
                triggers: {click: 'deal:connections'}},
      converter: {size: [17, geo.converter.d], anchor: [16, geo.converter.d / 2], image: 'converter', visibleWhen: {source: 'battery.present', truthy: true},
                  ink: {mask: 'converter.ink', from: geo.converter.from, to: geo.converter.to, source: 'battery.level', bands: {source: 'battery.state', eq: 'chg'}},
                  markers: [{at: geo.converter.mouth, shape: 'dot', when: {source: 'battery.state', eq: 'held'}}],
                  triggers: {click: 'deal:battery'}},
      matchbox: {size: [17, geo.matchbox], anchor: [16, geo.matchbox / 2], image: 'matchbox', triggers: {click: 'deal:power'}},
      paper: {size: [geo.paper.w, geo.paper.h], anchor: [0, geo.paper.h], image: 'paper', triggers: {click: 'notifications'},
              regions: [
                {id: 'writing', frames: {source: 'notifications.unread', min: 0, max: 6, images: 'writing'}},
                {id: 'clip', rect: geo.paper.clip, image: 'paperclip', triggers: {click: 'clipboard'}, tag: 'Clipboard history'}]}
    },
    rail: {items: [
      {element: 'tray', place: 'center'}, {element: 'nib'}, {system: 'rule'}, {system: 'workspaces'}, {system: 'rule'},
      {element: 'vial', hand: 'levels'}, {element: 'antenna', hand: 'connections'}, {element: 'converter', hand: 'battery'}, {element: 'matchbox', hand: 'power'},
      {system: 'hands'}, {system: 'spacer'}, {system: 'media'}, {system: 'rule'}, {system: 'clock'}, {foot: 'paper'}]},
    dock: {before: [], after: []},
    cards: {},
    hands: {},
    cardArt: {},
    pins: {},
    devices: dev,
    media: {seal: 'devices/seal.png', sealCracked: 'devices/seal-cracked.png'}
  };
}

// Laid over the default: moves the tray onto the paper, adds a desk hand dealt by a wax seal,
// a skin card in it, a dock button, and hover animations. Files are relative to this folder;
// the default's images are reached with "../default/…".
function example(geo) {
  const clip = geo.paper.clip;
  return {
    about: 'Example skin: copy to ~/.config/illuminated/skin/ and edit. Overrides and additions only; everything else comes from the default skin.',
    sheets: {clipWiggle: {file: 'rail/clip-wiggle.png', columns: 5}},
    images: {'tray.stamp': 'rail/tray-stamp.png', 'clip.wiggle': {sheet: 'clipWiggle', grid: [120, 120], start: 0, count: 5}, seal: '../default/devices/seal.png', inkwell: 'cards/inkwell.png'},
    elements: {
      nib: {animations: {hoverIn: {tween: {x: 1.5}, duration: 140}, hoverOut: {tween: {}, duration: 180}, press: {tween: {x: -1}, duration: 60}, release: {tween: {x: 1.5}, duration: 90}}},
      paper: {regions: [
        {id: 'writing', frames: {source: 'notifications.unread', min: 0, max: 6, images: 'writing'}},
        {id: 'tray', rect: [8, 15, 6, 6], image: 'tray.stamp', triggers: {click: 'tray'}, tag: 'Tray', pad: 6},
        {id: 'clip', rect: clip, image: 'paperclip', triggers: {click: 'clipboard'}, tag: 'Clipboard · {{clipboard.count}} {{clipboard.count|plural:entry}}',
         animations: {hoverIn: {frames: 'clip.wiggle', fps: 16, mode: 'once'}}}]},
      seal: {units: 'px', size: [26, 26], anchor: [13, 13], image: 'seal', triggers: {click: 'deal:desk'}, tag: 'Desk',
             animations: {hoverIn: {tween: {rotate: -12, scale: 1.08}, duration: 160, easing: 'outBack'}, hoverOut: {tween: {}, duration: 160}}},
      quiet: {units: 'px', size: [30, 30], anchor: [15, 15], image: 'tray.stamp', dither: false,
              markers: [{at: [25, 5], shape: 'dot', radius: 4, colour: '#ED4A49', when: {source: 'notifications.dnd', truthy: true}}],
              triggers: {click: 'dnd'}, tag: 'Do not disturb'},
      'inkwell-face': {units: 'px', size: [154, 215.6], image: 'inkwell', shadow: false, dither: true,
                       regions: [{id: 'cork', rect: [57, 20, 40, 40], triggers: {click: 'deal:levels'}, tag: 'Levels'}]}
    },
    rail: {items: [
      {element: 'seal', place: 'center'}, {element: 'nib'}, {system: 'rule'}, {system: 'workspaces'}, {system: 'rule'},
      {element: 'vial', hand: 'levels'}, {element: 'antenna', hand: 'connections'}, {element: 'converter', hand: 'battery'}, {element: 'matchbox', hand: 'power'},
      {system: 'hands'}, {system: 'spacer'}, {system: 'media'}, {system: 'rule'}, {system: 'clock'}, {foot: 'paper'}]},
    dock: {after: ['quiet']},
    cards: {inkwell: {title: 'Ink', face: 'inkwell-face', value: '{{volume|percent}}', orientation: 'portrait'}},
    hands: {desk: {label: 'Desk', cards: ['skin:inkwell', 'volume']}}
  };
}

(async () => {
  const {chromium} = require('playwright');
  const browser = await chromium.launch();
  const pg = await browser.newPage();
  const errors = [];
  pg.on('pageerror', e => errors.push(String(e)));
  await pg.setContent(page);
  const built = await pg.evaluate(() => window.build());
  await browser.close();
  if (errors.length) { console.error(errors.join('\n')); process.exit(1); }
  for (const sub of ['rail', 'devices']) fs.rmSync(path.join(out, sub), {recursive: true, force: true});
  for (const [p, url] of Object.entries(built.files)) { const f = path.join(out, p); fs.mkdirSync(path.dirname(f), {recursive: true}); fs.writeFileSync(f, Buffer.from(url.split(',')[1], 'base64')); }
  // The example skin: a worked example of overriding and adding (docs/SKINS.md, "Example").
  const exDir = path.join(path.dirname(out), 'example');
  fs.rmSync(exDir, {recursive: true, force: true});
  for (const [p, url] of Object.entries(built.ex)) { const f = path.join(exDir, p); fs.mkdirSync(path.dirname(f), {recursive: true}); fs.writeFileSync(f, Buffer.from(url.split(',')[1], 'base64')); }
  fs.writeFileSync(path.join(exDir, 'skin.json'), JSON.stringify(example(built.geo), null, 2) + '\n');
  // Materials (written by build-materials.cjs) are kept and merged in if present.
  const mfile = path.join(out, 'materials.json'), m = manifest(built.geo, built.dev);
  if (fs.existsSync(mfile)) m.materials = JSON.parse(fs.readFileSync(mfile, 'utf8'));
  const lfile = path.join(out, 'loupes.json');
  if (fs.existsSync(lfile)) m.loupes = JSON.parse(fs.readFileSync(lfile, 'utf8'));
  m.initial = 'materials/initial.png';
  fs.writeFileSync(path.join(out, 'skin.json'), JSON.stringify(m, null, 2) + '\n');
  console.log('wrote', Object.keys(built.files).length, 'images and skin.json to', out);
})();
