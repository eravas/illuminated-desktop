#!/usr/bin/env node
// Bakes the default and example skins' rail and dock objects into frame sheets for the QML
// skins (docs/SKINS.md): each look an object can show, already composited, dithered and
// shadowed by the shell's own finish (quickshell/skin/Compose.js), at 1× and @2x. The shell
// then shows a frame; it does no pixel work for skin objects.
//   node scripts/skin/bake-elements.cjs
// Inputs: scripts/skin/elements.json (the objects' looks: images, ink, markers, regions, in the
// pre-QML element format, kept only as the bake's source) and the skins' source images.
// Outputs: <skin>/elements/<name>.png and <name>-2x.png (not @2x: Qt would treat that as a 2-DPR image and halve sourceSize), one row of frames each; and
// scripts/skin/hulls.json (hit polygons in mm, for thin objects). Developer tool: needs
// Playwright's Chromium.
const path = require('node:path');
const fs = require('node:fs');
const {wrapped} = require('../../tests/visual/load.cjs');
const root = path.resolve(__dirname, '../..');
const skins = path.join(root, 'quickshell/skins');
const spec = JSON.parse(fs.readFileSync(path.join(__dirname, 'elements.json'), 'utf8'));
// Nominal life-size scale: the 24″ 1080p default (DeviceGeometry.PX_PER_MM["24"]).
const PXMM = 1920 / 531;
const shared = new Map();
const lib = [
  wrapped(path.join(__dirname, 'Compose.js'), 'Compose', shared),
  wrapped(path.join(__dirname, 'Skin.js'), 'Skin', shared),
].join('\n');

// Every image file a manifest names, as a data URL keyed by its manifest-relative path.
function images(manifest, dir) {
  const out = {};
  const add = f => { if (f && !out[f]) out[f] = 'data:image/png;base64,' + fs.readFileSync(path.join(dir, f)).toString('base64'); };
  for (const v of Object.values(manifest.images || {})) {
    if (typeof v === 'string') add(v); else if (v && v.file) add(v.file);
  }
  for (const s of Object.values(manifest.sheets || {})) add(s.file);
  return out;
}

const page = `<!doctype html><body><script>${lib}
const PXMM = ${PXMM};
const loaded = {};
async function load(files) {
  await Promise.all(Object.entries(files).map(([name, url]) => new Promise((ok, bad) => {
    const i = new Image(); i.onload = () => { loaded[name] = i; ok(); }; i.onerror = () => bad(new Error(name)); i.src = url; })));
}
// One finished look of an element, as RGBA, the way SkinElement.qml paints it.
function finished(manifest, id, state, D, live) {
  const el = manifest.elements[id], scale = Skin.scaleFor(Skin.unitsOf(manifest, el), PXMM);
  const margin = el.shadow === false ? 0 : 6, g = Compose.geometry(el.size, scale, margin, D);
  const c = document.createElement('canvas'); c.width = g.W; c.height = g.H;
  const ctx = c.getContext('2d', {willReadFrequently: true});
  const layer = (ref, rect) => {
    const r = rect || [0, 0, el.size[0], el.size[1]];
    ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.clearRect(0, 0, g.W, g.H);
    ctx.save(); ctx.scale(D, D);
    // Qt's Canvas drawImage resamples bilinearly; match it, so the finish dithers the same tones.
    ctx.imageSmoothingQuality = 'low';
    const img = loaded[ref.file], x = g.margin + r[0] * g.scale, y = g.margin + r[1] * g.scale, w = r[2] * g.scale, h = r[3] * g.scale;
    if (ref.rect) ctx.drawImage(img, ref.rect[0], ref.rect[1], ref.rect[2], ref.rect[3], x, y, w, h); else ctx.drawImage(img, x, y, w, h);
    ctx.restore();
    const out = new Uint8ClampedArray(ctx.getImageData(0, 0, g.W, g.H).data); ctx.clearRect(0, 0, g.W, g.H); return out;
  };
  const regions = (el.regions || []).filter(r => live.indexOf(r.id) >= 0).map(r => ({id: r.id, rect: r.rect || null, look: Skin.look(r, state), frame: null}));
  const px = Compose.compose({manifest, g, look: Skin.look(el, state), state, layer, frame: null, regions, inks: manifest.inks});
  Compose.finish(px, g, D, {dither: el.dither !== false, shadow: el.shadow !== false});
  return {px, W: g.W, H: g.H, g};
}
function sheet(frames) {
  const W = frames[0].W, H = frames[0].H, c = document.createElement('canvas'); c.width = W * frames.length; c.height = H;
  const x = c.getContext('2d');
  frames.forEach((f, i) => { const img = x.createImageData(W, H); img.data.set(f.px); x.putImageData(img, i * W, 0); });
  return c.toDataURL('image/png');
}
// Convex hull of a look's opaque pixels, in element units (for SkinItem.hitShape).
function hull(f) {
  const pts = [];
  for (let y = 0; y < f.H; y++) for (let x = 0; x < f.W; x++) if (f.px[(y * f.W + x) * 4 + 3] > 127) pts.push([x + 0.5, y + 0.5]);
  pts.sort((a, b) => a[0] - b[0] || a[1] - b[1]);
  const cross = (o, a, b) => (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0]);
  const lower = [], upper = [];
  for (const p of pts) { while (lower.length >= 2 && cross(lower[lower.length - 2], lower[lower.length - 1], p) <= 0) lower.pop(); lower.push(p); }
  for (const p of pts.slice().reverse()) { while (upper.length >= 2 && cross(upper[upper.length - 2], upper[upper.length - 1], p) <= 0) upper.pop(); upper.push(p); }
  const g = f.g, units = lower.slice(0, -1).concat(upper.slice(0, -1)).map(p => [+((p[0] / g.D - g.margin) / g.scale).toFixed(2), +((p[1] / g.D - g.margin) / g.scale).toFixed(2)]);
  return units;
}
window.bake = async function (jobs, files) {
  await load(files);
  const out = {}, hulls = {};
  for (const job of jobs) for (const D of [1, 2]) {
    const frames = job.states.map(s => finished(job.manifest, job.element, s.values, D, s.live || []));
    out[job.out + (D === 2 ? '-2x' : '') + '.png'] = sheet(frames);
    if (job.hull && D === 2) hulls[job.out] = hull(frames[0]);
  }
  return {out, hulls};
};
</script></body>`;

// ── jobs ──
const def = spec.default, ex = spec.example;
const range = (n, f) => Array.from({length: n}, (_, i) => f(i));
const LEVELS = 24;   // InkFill steps
const modes = ['light', 'dark'];
function jobs() {
  const d = (element, out, states, extra) => ({manifest: def, element, out: 'default/elements/' + out, states, ...extra});
  const base = {'battery.present': true};
  const list = [
    d('tray', 'tray', modes.map(m => ({values: {mode: m}}))),
    d('nib', 'nib', [{values: {}}], {hull: true}),
    d('matchbox', 'matchbox', [{values: {}}]),
    d('vial', 'vial', range(LEVELS + 1, i => ({values: {volume: i / LEVELS}}))),
    d('antenna', 'antenna', [].concat(...modes.map(m => range(5, s => ({values: {mode: m, 'network.stage': s}})).concat([{values: {mode: m, 'network.stage': 0, 'network.connecting': true}}])))),
    // Discharging, then charging (bands), then held on AC (the canary dot): 25 levels each.
    d('converter', 'converter', [].concat(...['dis', 'chg', 'held'].map(st => range(LEVELS + 1, i => ({values: {...base, 'battery.state': st, 'battery.level': i / LEVELS}}))))),
    // Unread 0–6, without and with the paperclip (it shows while clipboard history is on).
    d('paper', 'paper', [].concat(...[[], ['clip']].map(live => range(7, n => ({values: {'notifications.unread': n}, live: ['writing'].concat(live)}))))),
    d('paperclip', 'paperclip', [{values: {}}], {hull: true}),
  ];
  const e = (element, out, states, extra) => ({manifest: ex, element, out: 'example/elements/' + out, states, ...extra});
  list.push(
    e('seal', 'seal', [{values: {}}]),
    e('quiet', 'quiet', [{values: {'notifications.dnd': false}}, {values: {'notifications.dnd': true}}]),
    e('paper', 'paper', range(7, n => ({values: {'notifications.unread': n}, live: ['writing', 'tray']}))),
    e('clip', 'clip', range(5, i => ({values: {frame: i}}))),
    e('inkwell-face', 'inkwell-face', [{values: {}}]));
  return list;
}

(async () => {
  // elements.json names files relative to quickshell/skins/.
  const files = {...images(def, skins), ...images(ex, skins)};
  const {chromium} = require('playwright');
  const browser = await chromium.launch();
  const pg = await browser.newPage();
  const errors = [];
  pg.on('pageerror', e => errors.push(String(e)));
  await pg.setContent(page);
  const {out, hulls} = await pg.evaluate(([j, f]) => window.bake(j, f), [jobs(), files]);
  await browser.close();
  if (errors.length) { console.error(errors.join('\n')); process.exit(1); }
  for (const [p, url] of Object.entries(out)) {
    const f = path.join(skins, p); fs.mkdirSync(path.dirname(f), {recursive: true});
    fs.writeFileSync(f, Buffer.from(url.split(',')[1], 'base64'));
  }
  fs.writeFileSync(path.join(__dirname, 'hulls.json'), JSON.stringify(hulls, null, 1) + '\n');
  console.log('baked', Object.keys(out).length, 'sheets');
})();
