const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const m = {};
vm.createContext(m);
vm.runInContext(fs.readFileSync('quickshell/artifacts/CardModel.js', 'utf8'), m);
const defaults = JSON.parse(fs.readFileSync('quickshell/config/defaults.json', 'utf8'));

function colours(mode) {
  const p = defaults.palettes[mode], other = defaults.palettes[mode === 'light' ? 'dark' : 'light'];
  return {...defaults.semantic, ...p, edgeInverted: other.edge};
}
function luminance(hex) {
  const v = [1, 3, 5].map(i => parseInt(hex.slice(i, i + 2), 16) / 255).map(c => c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4);
  return 0.2126 * v[0] + 0.7152 * v[1] + 0.0722 * v[2];
}
function contrast(a, b) { const [x, y] = [luminance(a), luminance(b)].sort((p, q) => q - p); return (x + 0.05) / (y + 0.05); }

test('layout: ~10 px frame and ~19 % chin on the default portrait card; chin and art never overlap', () => {
  const g = m.layout(154, 154 * 7 / 5);
  assert.equal(g.frame, 10);
  assert.equal(g.chin, Math.round(215.6 * 0.19));
  for (const [w, h] of [[154, 215.6], [248, 177], [100, 140], [320, 448]]) {
    const l = m.layout(w, h);
    assert(l.art.y + l.art.height <= l.chinArea.y + 1e-9);
    assert(l.chinArea.y + l.chinArea.height <= h - l.frame + 1e-9);
    assert(l.dogEar >= 12);
  }
});

test('battery: level, charging bands, held wash, full-on-power and the low-charge numeral', () => {
  const c = colours('dark');
  const discharging = m.battery({present: true, level: .64, charging: false, plugged: false, full: false}, c, false);
  assert.equal(discharging.surface.wash.colour, c.battery);
  assert.equal(discharging.surface.wash.axis, 'y');
  assert.equal(discharging.surface.bands, null);
  assert.equal(discharging.glyph, '');
  assert.equal(discharging.value, '64%');
  const charging = m.battery({present: true, level: 1, charging: true, plugged: false, full: false}, c, false);
  assert.equal(charging.surface.bands.colour, c.power, 'charging stays visible at 100% through the bands');
  assert.equal(charging.glyph, 'ϟ');
  const held = m.battery({present: true, level: .92, charging: false, plugged: true, full: false}, c, false);
  assert.equal(held.surface.wash.colour, c.power);
  assert.equal(held.surface.bands, null, 'settled state is solid, not banded');
  assert.equal(held.value, '92% • held');
  assert.equal(held.glyph, '⌁');
  const full = m.battery({present: true, level: 1, charging: false, plugged: true, full: true}, c, false);
  assert.equal(full.surface.wash.colour, c.battery, 'full on external power stays green');
  assert.equal(full.glyph, 'ϟ');
  assert(!full.value.includes('held'));
  const low = m.battery({present: true, level: .12, charging: false, plugged: false, full: false}, c, true);
  assert(low.numeral && low.value === '');
  const lowCharging = m.battery({present: true, level: .12, charging: true, plugged: false, full: false}, c, true);
  assert(lowCharging.glyph === '' && lowCharging.surface.bands, 'numeral clears the glyph; bands still show charging');
  assert(!m.battery({present: true, level: .12, charging: false, plugged: false, full: false}, c, false).numeral);
  assert(!m.battery({present: true, level: .2, charging: false, plugged: false, full: false}, c, true).numeral);
  assert.equal(m.battery({present: false}, c, true).value, '—');
});

test('level cards: wash runs left to right; mute desaturates the fill and names the state', () => {
  const c = colours('light');
  const v = m.level('volume', {available: true, level: .4, muted: false}, c);
  assert.equal(v.surface.wash.colour, c.volume);
  assert.equal(v.surface.wash.axis, 'x');
  const muted = m.level('volume', {available: true, level: .4, muted: true}, c);
  assert.equal(muted.surface.wash.colour, c.volumeMuted);
  assert.equal(muted.surface.wash.level, .4, 'mute is independent of level');
  assert.equal(muted.value, 'Muted');
  assert.equal(muted.surface.base, c.cardstock, 'mute no longer red-shifts the cardstock');
  assert.equal(m.level('brightness', {available: true, level: .5}, c).surface.wash.colour, c.brightness);
});

test('art indicators change uniformly and never take a state colour', () => {
  assert.deepEqual({...m.art('volume', 0, true)}, {saturation: .15, luminance: 1});
  assert.deepEqual({...m.art('brightness', 0, true)}, {saturation: 1, luminance: .4});
  assert.deepEqual({...m.art('battery', 1, true)}, {saturation: 1, luminance: 1});
  assert.deepEqual({...m.art('battery', 0, false)}, {saturation: 1, luminance: 1});
});

test('network: off, connecting bands, four patina stages, failed red bands', () => {
  const c = colours('dark');
  assert.equal(m.network({enabled: false}, c).value, 'Off');
  assert.equal(m.network({enabled: true, connecting: true}, c).surface.bands.colour, c.verdigris);
  const coverage = Array.from([1, 2, 3, 4], stage => m.network({enabled: true, connected: true, stage, name: 'home'}, c).surface.patina.coverage);
  assert.deepEqual(coverage, [.17, .26, .36, .80]);
  assert.equal(m.network({enabled: true, connected: true, stage: 4}, c).surface.base, c.copper);
  assert.equal(m.network({enabled: true, connected: true, stage: 2}, c).glyph, '▂▄');
  const failed = m.network({enabled: true, failed: true, connecting: true}, c);
  assert.equal(failed.surface.bands.colour, c.critical);
  assert.equal(failed.value, 'Failed');
  assert.deepEqual([0, .01, .25, .26, .5, .75, .76, 1].map(x => m.signalStage(x)), [0, 1, 1, 2, 2, 3, 4, 4]);
});

test('bluetooth: idle chin tint, connecting bands, connected solid, failed red', () => {
  const c = colours('light');
  assert.equal(m.bluetooth({available: true, enabled: false}, c).value, 'Off');
  const idle = m.bluetooth({available: true, enabled: true, connected: 0}, c);
  assert.equal(idle.surface.chinFill, c.bluetooth);
  assert.equal(idle.surface.base, c.cardstock);
  assert.equal(m.bluetooth({available: true, enabled: true, connecting: true}, c).surface.bands.colour, c.bluetooth);
  const on = m.bluetooth({available: true, enabled: true, connected: 2}, c);
  assert.equal(on.surface.base, c.bluetooth);
  assert.equal(on.value, '2 devices');
  assert.equal(m.bluetooth({available: true, enabled: true, failed: true}, c).surface.bands.colour, c.critical);
});

test('power set: Sleep is mode-biased with its own ink; Shut Down solid red; Reboot banded with a red chin', () => {
  for (const mode of ['light', 'dark']) {
    const c = colours(mode);
    const sleep = m.power('suspend', c).surface;
    assert.equal(sleep.base, c.sleepCard);
    assert(contrast(sleep.ink, sleep.base) >= 4.5, `${mode} Sleep ink ${contrast(sleep.ink, sleep.base).toFixed(2)}`);
    assert.equal(m.power('poweroff', c).surface.base, c.critical);
    const reboot = m.power('reboot', c).surface;
    assert.equal(reboot.bands.colour, c.critical);
    assert.equal(reboot.chinFill, c.critical);
    assert.equal(reboot.chinInk, c.onFill);
    const back = m.back('reboot', reboot, c);
    assert.equal(back.interior.base, c.critical);
    assert.equal(back.interior.stripe, c.criticalTonal);
    assert.equal(back.bands.colour, c.critical, 'frame bands continue on the back');
  }
});

test('session card modes and wording', () => {
  // As ServiceCard builds its spec: the kind's behaviour (Kinds.js) over the config entry.
  const k = {}; vm.createContext(k);
  vm.runInContext(fs.readFileSync('quickshell/artifacts/kinds/Kinds.js', 'utf8').replace('.pragma library', ''), k);
  const spec = kind => ({...defaults.cards[kind], ...k.meta(kind)});
  assert.equal(m.sessionMode(spec('suspend')), 'menu');
  assert.equal(m.sessionMode(spec('poweroff')), 'confirm');
  assert.equal(m.sessionMode(spec('reboot')), 'confirm');
  assert.equal(m.sessionMode(spec('lock')), 'act');
  assert.equal(m.sentence('Log Out') + '?', 'Log out?');
  assert.equal(m.sentence('Shut Down'), 'Shut down');
});

test('per-region ink: text over a wash takes onFill, over cardstock takes the mode ink', () => {
  const c = colours('dark');
  const s = m.battery({present: true, level: .5, charging: false, plugged: false, full: false}, c, false).surface;
  assert.equal(m.inkAt(s, 10, 190, 154, 216), c.onFill);
  assert.equal(m.inkAt(s, 10, 20, 154, 216), c.ink);
  const reboot = m.back('reboot', m.power('reboot', c).surface, c);
  assert.equal(m.inkAt(reboot, 10, 20, 154, 216), c.onFill);
});

test('contrast gates for every ink the cards use (DESIGN-SYSTEM.md §3.8)', () => {
  const s = defaults.semantic;
  for (const fill of ['volume', 'volumeMuted', 'brightness', 'power', 'battery', 'batteryTonal', 'bluetooth', 'copper', 'verdigris', 'criticalTonal'])
    assert(contrast(s.onFill, s[fill]) >= 4.5, `${fill} ${contrast(s.onFill, s[fill]).toFixed(2)}`);
  assert(contrast(s.onFill, s.critical) >= 4.5, 'red is the one fill below 7:1, but not below 4.5:1');
  for (const mode of ['light', 'dark']) {
    const p = defaults.palettes[mode];
    for (const surface of ['cardstock', 'cardstockTonal', 'paper'])
      assert(contrast(p.ink, p[surface]) >= 7, `${mode} ink on ${surface}`);
    assert(contrast(p.mutedInk, p.paper) >= 4.5, `${mode} secondary ink`);
  }
});

test('durations', () => {
  assert.equal(m.duration(0), '—');
  assert.equal(m.duration(3 * 3600 + 5 * 60), '3:05');
});
