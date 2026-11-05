// Static QML checks for failures that host tests cannot otherwise see.
const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

function qmlFiles(dir) {
  return fs.readdirSync(dir, {withFileTypes: true}).flatMap(e =>
    e.isDirectory() ? qmlFiles(path.join(dir, e.name)) : e.name.endsWith('.qml') ? [path.join(dir, e.name)] : []);
}

// Body of every `Loader {` block, brace-matched (strings and comments are rare
// enough in this tree that a plain brace count is sufficient).
function loaderBodies(text) {
  const bodies = [];
  const re = /\bLoader\s*\{/g;
  let m;
  while ((m = re.exec(text))) {
    let depth = 1, i = m.index + m[0].length, start = i;
    for (; i < text.length && depth; i++) { if (text[i] === '{') depth++; else if (text[i] === '}') depth--; }
    // Only the Loader's own level: drop nested blocks (its loaded component may set implicit sizes).
    let own = '', d = 0;
    for (const ch of text.slice(start, i - 1)) { if (ch === '{') d++; else if (ch === '}') d--; else if (d === 0) own += ch; }
    bodies.push(own);
  }
  return bodies;
}

test('no Loader assigns implicitWidth/implicitHeight (read-only on Loader; QML load fails)', () => {
  for (const file of qmlFiles('quickshell').concat(qmlFiles('tests/runtime'))) {
    for (const body of loaderBodies(fs.readFileSync(file, 'utf8')))
      assert.doesNotMatch(body, /\bimplicit(Width|Height)\s*:/, file);
  }
});

test('the guard catches the v4 tray Loader', () => {
  const v4 = 'Component { id: tray; Loader { property bool wanted: true; implicitWidth: item ? item.implicitWidth : 0; sourceComponent: Component { TrayStrip { implicitWidth: 4 } } } }';
  assert.match(loaderBodies(v4)[0], /implicitWidth\s*:/);
  const fixed = 'Loader { active: true; sourceComponent: Component { TrayStrip { implicitWidth: 4 } } }';
  assert.doesNotMatch(loaderBodies(fixed)[0], /implicitWidth\s*:/);
});

// Item properties (most are FINAL) that a QML type cannot redeclare; Qt refuses
// to load the component. v5's CardFill declared `bottom` and no card loaded.
const RESERVED = ['id', 'x', 'y', 'z', 'width', 'height', 'implicitWidth', 'implicitHeight', 'opacity', 'visible',
  'enabled', 'clip', 'parent', 'children', 'data', 'resources', 'anchors', 'left', 'right', 'top', 'bottom',
  'horizontalCenter', 'verticalCenter', 'baseline', 'baselineOffset', 'rotation', 'scale', 'state', 'states',
  'transitions', 'transform', 'transformOrigin', 'smooth', 'antialiasing', 'focus', 'activeFocus',
  'activeFocusOnTab', 'layer', 'childrenRect', 'containmentMask', 'objectName'];
function declared(text) {
  // Declarations start a line or follow `{` / `;` (one-line objects).
  return [...text.matchAll(/(?:^|[{;])\s*(?:readonly\s+|required\s+|default\s+)*property\s+[\w<>.]+\s+(\w+)/gm)].map(m => m[1]);
}

// Root types that are not Items (they may use names such as `state`).
const NOT_ITEMS = ['QtObject', 'Singleton', 'Scope', 'ShellRoot'];
function rootType(text) { const m = text.match(/^([A-Z][\w.]*)\s*\{/m); return m ? m[1] : ''; }

test('no QML property redeclares a reserved Item property', () => {
  for (const file of qmlFiles('quickshell').concat(qmlFiles('tests/runtime'))) {
    const text = fs.readFileSync(file, 'utf8');
    assert(!declared(text).includes('id'), `${file} declares a property named id (reserved in every QML object)`);
    if (NOT_ITEMS.includes(rootType(text))) continue;
    for (const name of declared(text))
      assert(!RESERVED.includes(name), `${file} declares property ${name}`);
  }
});

test('the reserved-name guard catches the v5 CardFill', () => {
  assert.deepEqual(declared('Item {\n    readonly property real bottom: 1\n    property var r: 0\n}'), ['bottom', 'r']);
  assert.deepEqual(declared('QtObject { id: seed; property int id: 0; property string name: "" }'), ['id', 'name']);
});

test('putImageData always passes the dirty rectangle (Qt 6.12 ignores the 3-argument form)', () => {
  const files = qmlFiles('quickshell').concat(fs.readdirSync('quickshell/materials').filter(f => f.endsWith('.js')).map(f => path.join('quickshell/materials', f)));
  for (const file of files) for (const m of fs.readFileSync(file, 'utf8').matchAll(/putImageData\(([^()]*(?:\([^()]*\))*[^()]*)\)/g))
    assert.equal(m[1].split(',').length, 7, `${file}: ${m[0]}`);
});

// Quickshell resolves a directory import (`import "kinds"`) reliably only through a qmldir:
// without one, the same file loads from one entry point and is "not a type" when shell.qml
// is reached through a Loader (found with artifacts/kinds, single-config suite).
test('every directory imported by path has a qmldir listing its components', () => {
  for (const file of qmlFiles('quickshell')) {
    const text = fs.readFileSync(file, 'utf8');
    for (const m of text.matchAll(/^import\s+"([^"]+)"\s*$/gm)) {
      if (m[1].endsWith('.js')) continue;
      const dir = path.join(path.dirname(file), m[1]);
      const qmldir = path.join(dir, 'qmldir');
      assert(fs.existsSync(qmldir), `${file}: ${m[1]} has no qmldir`);
      const listed = fs.readFileSync(qmldir, 'utf8');
      for (const qml of fs.readdirSync(dir).filter(n => n.endsWith('.qml') && /^[A-Z]/.test(n)))
        assert(listed.includes(qml), `${qmldir} does not list ${qml}`);
    }
  }
});
