const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

// Execute the actual QML JS policy, without creating a second implementation.
const policy = {};
vm.createContext(policy);
vm.runInContext(fs.readFileSync(path.join(__dirname,
    '../quickshell/services/WorkspaceLogic.js'), 'utf8'), policy);
const ids = (list) => Array.from(list, (workspace) => workspace.id);
const ws = (id, name, output = 'eDP-1') => ({id, name, monitor: {name: output}});

test('named ordinary workspaces survive negative IDs; scratchpads do not', () => {
    const list = [ws(3, '3'), ws(-1337, 'Reading'), ws(-99, 'special:magic'),
        ws(-98, 'special'), ws(1, '1'), ws(-97, 'specialist')];
    assert.deepEqual(ids(policy.ordinaryWorkspaces(list, 'eDP-1', false)),
        [-1337, -97, 1, 3]);
    assert.deepEqual(ids(list), [3, -1337, -99, -98, 1, -97], 'must not reorder the source model');
});

test('workspace migration is reflected by filtering current monitor ownership', () => {
    const moving = ws(2, '2', 'DP-1');
    const list = [ws(1, '1'), moving];
    assert.deepEqual(ids(policy.ordinaryWorkspaces(list, 'eDP-1', false)), [1]);
    moving.monitor = {name: 'eDP-1'};
    assert.deepEqual(ids(policy.ordinaryWorkspaces(list, 'eDP-1', false)), [1, 2]);
    assert.deepEqual(ids(policy.ordinaryWorkspaces(list, 'DP-1', false)), []);
});

test('missing monitor never exposes every workspace while output discovery runs', () => {
    assert.deepEqual(ids(policy.ordinaryWorkspaces([ws(1, '1')], '', true)), []);
    assert.deepEqual(ids(policy.ordinaryWorkspaces([null, {id: 2, name: '2', monitor: null}], 'eDP-1', false)), []);
});

test('all-output mode retains ordinary workspaces from other outputs', () => {
    assert.deepEqual(ids(policy.ordinaryWorkspaces([ws(2, '2', 'DP-1'), ws(1, '1')], 'eDP-1', true)), [1, 2]);
});

test('labels preserve punctuation, Unicode, and markup as literal data', () => {
    const name = 'Lecture "A" \\ notes · 日本語 <b>title</b>';
    assert.equal(policy.workspaceLabel(ws(-1, name)), name);
    assert.equal(policy.workspaceLabel(null), '');
    assert.equal(policy.workspaceLabel({id: 7, name: ''}), '7');
});
