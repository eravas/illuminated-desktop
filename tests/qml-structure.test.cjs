// Structural QML checks that need no Qt: balanced delimiters, relative imports that exist,
// and every object type resolvable (Qt/Quickshell, an imported directory's qmldir or file,
// or an inline component). No qmllint or Quickshell is available where these run, so this
// catches the typo and missing-import class of load failures before a runtime test.
const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

function qmlFiles(dir) {
  return fs.readdirSync(dir, {withFileTypes: true}).flatMap(e =>
    e.isDirectory() ? qmlFiles(path.join(dir, e.name)) : e.name.endsWith('.qml') ? [path.join(dir, e.name)] : []);
}
// Strip comments and string/template literals (keeping line structure) for scanning.
function code(text) {
  let out = '', i = 0;
  while (i < text.length) {
    const c = text[i], n = text[i + 1];
    if (c === '/' && n === '/') { while (i < text.length && text[i] !== '\n') i++; continue; }
    if (c === '/' && n === '*') { i += 2; while (i < text.length && !(text[i] === '*' && text[i + 1] === '/')) { if (text[i] === '\n') out += '\n'; i++; } i += 2; continue; }
    if (c === '"' || c === "'" || c === '`') {
      const q = c; out += q; i++;
      while (i < text.length && text[i] !== q) { if (text[i] === '\\') i++; else if (text[i] === '\n' && q !== '`') break; i++; }
      out += q; i++; continue;
    }
    // Regex literals after ( , = : ! & | ? { } ; return
    if (c === '/' && /[(,=:!&|?{};]\s*$|return\s*$/.test(out.slice(-12))) {
      out += '/'; i++;
      while (i < text.length && text[i] !== '/' && text[i] !== '\n') { if (text[i] === '\\') i++; else if (text[i] === '[') { while (i < text.length && text[i] !== ']') i++; } i++; }
      out += '/'; i++; continue;
    }
    out += c; i++;
  }
  return out;
}
const EXTERNAL = new Set(`Item Rectangle Text Image Canvas Column Row Flow Grid Repeater MouseArea HoverHandler WheelHandler TapHandler Timer Behavior
NumberAnimation ColorAnimation SequentialAnimation ParallelAnimation ScriptAction PropertyAnimation Loader Component Connections QtObject FocusScope Flickable
TextMetrics Rotation Translate Scale TextInput TextEdit ListView ColumnLayout RowLayout GridLayout Button Label TextField ScrollView ToolTip Slider Switch CheckBox
ShellRoot Scope Variants PanelWindow PopupWindow FloatingWindow Region Singleton SystemClock Process StdioCollector SplitParser FileView IpcHandler Socket
PwObjectTracker QsMenuOpener Instantiator LazyLoader Greetd ObjectModel NotificationServer Shortcut Keys Gradient GradientStop Font Window Transition State
PropertyChanges ComboBox TextArea ScrollBar ScriptModel FileViewAdapter JsonAdapter Retainable LazyLoader IconImage ToplevelManager
WlSessionLock WlSessionLockSurface PamContext PolkitAgent MultiEffect`.split(/\s+/));

function localTypes(dir) {
  const set = new Set();
  const qmldir = path.join(dir, 'qmldir');
  if (fs.existsSync(qmldir)) for (const line of fs.readFileSync(qmldir, 'utf8').split('\n')) {
    const m = line.trim().match(/^(?:singleton\s+)?([A-Z]\w*)\s+[\d.]+\s+(\S+\.qml)$/);
    if (m) { set.add(m[1]); assert(fs.existsSync(path.join(dir, m[2])), `${qmldir}: ${m[2]} missing`); }
  }
  for (const f of fs.readdirSync(dir)) if (/^[A-Z]\w*\.qml$/.test(f)) set.add(f.slice(0, -4));
  return set;
}

for (const file of qmlFiles('quickshell')) {
  test(`structure: ${file}`, () => {
    const raw = fs.readFileSync(file, 'utf8'), src = code(raw), dir = path.dirname(file);
    // Balanced delimiters.
    const stack = [], pairs = {')': '(', ']': '[', '}': '{'};
    src.split('\n').forEach((line, n) => { for (const ch of line) {
      if ('([{'.includes(ch)) stack.push([ch, n + 1]);
      else if (pairs[ch]) { const top = stack.pop(); assert(top && top[0] === pairs[ch], `${file}:${n + 1} unbalanced ${ch}`); }
    }});
    assert.equal(stack.length, 0, `${file}: unclosed ${stack.length && stack[stack.length - 1][0]} from line ${stack.length && stack[stack.length - 1][1]}`);
    // Relative imports exist; collect the types they provide.
    const known = new Set([...EXTERNAL, ...localTypes(dir)]);
    for (const m of raw.matchAll(/^import\s+"([^"]+)"(?:\s+as\s+(\w+))?/gm)) {
      const target = path.join(dir, m[1]);
      assert(fs.existsSync(target), `${file}: import ${m[1]} does not exist`);
      if (fs.statSync(target).isDirectory()) localTypes(target).forEach(t => known.add(t));
    }
    for (const m of src.matchAll(/^\s*component\s+([A-Z]\w*)\s*:/gm)) known.add(m[1]);
    // Object declarations: a capitalised type name followed by `{` (not after `.` or `:`-bound JS).
    for (const m of src.matchAll(/(^|[\s;{:\[,])([A-Z][A-Za-z0-9_]*)\s*\{/gm)) {
      const name = m[2];
      if (known.has(name)) continue;
      const before = src.slice(Math.max(0, m.index - 30), m.index + m[1].length);
      if (/\b(new|return|case)\s*$/.test(before) || /[=(?]\s*$/.test(before) && !/:\s*$/.test(before)) continue;
      assert.fail(`${file}: unknown type ${name}`);
    }
  });
}
