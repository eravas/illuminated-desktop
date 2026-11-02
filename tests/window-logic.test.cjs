const {test} = require('node:test');
const assert = require('node:assert/strict');
const {load} = require('./visual/load.cjs');
const W = load('quickshell/compositors/WindowLogic.js');
const fs = require('node:fs');
const defaults = JSON.parse(fs.readFileSync('quickshell/config/defaults.json', 'utf8'));

test('addresses normalise to 0x… and reject anything else', () => {
  assert.equal(W.address('55d3a1b2'), '0x55d3a1b2');
  assert.equal(W.address('0xABC'), '0xabc');
  assert.equal(W.address('1; exit'), '');
});
test('dispatch templates: Lua and legacy, unsafe arguments refused', () => {
  const t = defaults.dock.dispatch;
  assert.equal(W.dispatchFor('focus', true, t, {address: 'abc'}), 'hl.dsp.focus({ window = "address:0xabc" })');
  assert.equal(W.dispatchFor('move', false, t, {address: '0xabc', workspace: '3'}), 'movetoworkspacesilent 3,address:0xabc');
  assert.equal(W.dispatchFor('move', true, t, {address: '0xabc', workspace: 'special:minimized'}),
    'hl.dsp.window.move({ workspace = "special:minimized", window = "address:0xabc", follow = false })');
  assert.equal(W.dispatchFor('move', true, t, {address: '0xabc', workspace: '3" }) hl.dsp.exit() --'}), '');
});
test('dock windows: opening order kept, minimised windows marked, scratchpads hidden', () => {
  const ws = (id, name) => ({id, name});
  const tl = [
    {address: 'a1', title: 'kitty', workspace: ws(1, '1'), wayland: {appId: 'kitty'}},
    {address: 'b2', title: 'notes', workspace: ws(-98, 'special:minimized'), lastIpcObject: {class: 'org.gnome.TextEditor'}},
    {address: 'c3', title: 'scratch', workspace: ws(-99, 'special:scratch')},
    {address: 'd4', title: 'firefox', workspace: ws(8, '8'), lastIpcObject: {class: 'firefox'}}];
  const out = W.hyprlandWindows(tl, '0xd4', 'minimized');
  assert.deepEqual([...out].map(w => w.id), ['0xa1', '0xb2', '0xd4']);
  assert.equal(out[1].minimized, true); assert.equal(out[1].workspace, 0); assert.equal(out[1].appId, 'org.gnome.TextEditor');
  assert.equal(out[2].focused, true); assert.equal(out[2].workspace, 8);
});
