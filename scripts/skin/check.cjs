#!/usr/bin/env node
// Validates a skin with the shell's own rules (quickshell/skin/Skin.js `check`), so `illuminated
// doctor` and the shell agree on what is an error. Merges the user skin over the default first,
// as SkinStore does. Prints one error per line; exit 1 if any.
//   node scripts/skin/check.cjs <quickshell dir> <user skin.json>
const fs = require('node:fs'), path = require('node:path'), vm = require('node:vm');
const [qs, userFile] = process.argv.slice(2);
const src = fs.readFileSync(path.join(qs, 'skin/Skin.js'), 'utf8').replace(/^\.pragma\s+library\s*$/m, '');
const ctx = vm.createContext({Math, JSON});
vm.runInContext(src, ctx, {filename: 'Skin.js'});
const read = f => JSON.parse(fs.readFileSync(f, 'utf8'));
let errors;
try {
  const defDir = path.join(qs, 'skins/default'), userDir = path.dirname(path.resolve(userFile));
  const merged = ctx.merge(ctx.absolutise(read(path.join(defDir, 'skin.json')), defDir + '/'), ctx.absolutise(read(userFile), userDir + '/'));
  errors = Array.from(ctx.check(merged));
} catch (e) { errors = ['skin.json: ' + e.message]; }
for (const e of errors) console.log(e);
process.exit(errors.length ? 1 : 0);
