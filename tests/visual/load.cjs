// Loads the shell's `.pragma library` JavaScript outside QML: strips the pragma, resolves
// `.import "X.js" as Name` against sibling files, and exposes every top-level declaration.
// Used by the Node tests and (as source text) by the Chromium visual harness.
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

function names(code) {
  return [...code.matchAll(/^(?:function\s+(\w+)|var\s+(\w+))/gm)].map(m => m[1] || m[2]);
}
// Source text that, evaluated in a browser, defines `var <as> = {...}` for the file.
// Each file is included once (QML shares .pragma library modules too); a second import under
// another name becomes an alias of the first.
function wrapped(file, as, seen = new Map()) {
  file = path.resolve(file);
  if (seen.has(file)) { const names = seen.get(file); if (names.includes(as)) return ''; names.push(as); return `var ${as} = ${names[0]};\n`; }
  seen.set(file, [as]);
  const dir = path.dirname(file);
  let code = fs.readFileSync(file, 'utf8');
  const imports = [...code.matchAll(/^\.import\s+"([^"]+)"\s+as\s+(\w+)\s*$/gm)];
  let pre = '';
  for (const [, rel, name] of imports) {
    pre += wrapped(path.join(dir, rel), name, seen);
  }
  code = code.replace(/^\.pragma\s+library\s*$/m, '').replace(/^\.import\s+.*$/gm, '');
  const exported = names(code).map(n => `${n}: typeof ${n} === "undefined" ? undefined : ${n}`).join(', ');
  return `${pre}var ${as} = (function () {\n${code}\nreturn {${exported}};\n})();\n`;
}
// Node: a module object with every top-level declaration of the file.
function load(file, extra = {}) {
  const ctx = vm.createContext({console, Math, ...extra});
  vm.runInContext(wrapped(path.resolve(file), '__module'), ctx, {filename: file});
  return ctx.__module;
}
module.exports = {load, wrapped};
