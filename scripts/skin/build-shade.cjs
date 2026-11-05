#!/usr/bin/env node
// The vellum texture as a shade tile: black, alpha = 1 − r of the skin's vellum field. Over a
// Rectangle of paper × (1 + amp), at opacity 2·amp/(1 + amp), it reproduces the painter's
// paper × (1 + (r − 0.5)·2·amp) exactly, with no pixel work in the shell (Vellum.qml).
//   node scripts/skin/build-shade.cjs [skin dir]   (after changing materials/vellum.png)
const path = require('node:path');
const png = require('./png.cjs');
const dir = path.resolve(process.argv[2] || path.join(__dirname, '../../quickshell/skins/default'));
const v = png.read(path.join(dir, 'materials/vellum.png')), out = new Uint8Array(v.data.length);
for (let i = 0; i < v.data.length; i += 4) out[i + 3] = 255 - v.data[i];
png.write(path.join(dir, 'materials/vellum-shade.png'), v.width, v.height, out);
console.log('wrote', path.join(dir, 'materials/vellum-shade.png'));
