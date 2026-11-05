// Minimal 8-bit PNG read/write (RGB/RGBA/grey, non-interlaced) with Node's zlib: enough for the
// skin's own images. read(file) → {width, height, data: RGBA Uint8Array}; write(file, w, h, rgba).
const fs = require('node:fs');
const zlib = require('node:zlib');
function read(file) {
  const b = fs.readFileSync(file);
  let p = 8, width, height, depth, type, idat = [];
  while (p < b.length) {
    const len = b.readUInt32BE(p), kind = b.toString('ascii', p + 4, p + 8), body = b.subarray(p + 8, p + 8 + len);
    if (kind === 'IHDR') { width = body.readUInt32BE(0); height = body.readUInt32BE(4); depth = body[8]; type = body[9]; if (body[12]) throw new Error(file + ': interlaced'); }
    else if (kind === 'IDAT') idat.push(body);
    else if (kind === 'IEND') break;
    p += 12 + len;
  }
  if (depth !== 8) throw new Error(file + ': only 8-bit PNG');
  const ch = {0: 1, 2: 3, 4: 2, 6: 4}[type]; if (!ch) throw new Error(file + ': palette PNG');
  const raw = zlib.inflateSync(Buffer.concat(idat)), stride = width * ch, out = new Uint8Array(width * height * 4);
  let prev = new Uint8Array(stride), row = new Uint8Array(stride);
  for (let y = 0; y < height; y++) {
    const f = raw[y * (stride + 1)], src = raw.subarray(y * (stride + 1) + 1, (y + 1) * (stride + 1));
    for (let x = 0; x < stride; x++) {
      const a = x >= ch ? row[x - ch] : 0, up = prev[x], c = x >= ch ? prev[x - ch] : 0;
      const pr = f === 0 ? 0 : f === 1 ? a : f === 2 ? up : f === 3 ? (a + up) >> 1 : (() => { const q = a + up - c, pa = Math.abs(q - a), pb = Math.abs(q - up), pc = Math.abs(q - c); return pa <= pb && pa <= pc ? a : pb <= pc ? up : c; })();
      row[x] = (src[x] + pr) & 255;
    }
    for (let x = 0; x < width; x++) {
      const o = (y * width + x) * 4, i = x * ch;
      if (ch === 1 || ch === 2) { out[o] = out[o + 1] = out[o + 2] = row[i]; out[o + 3] = ch === 2 ? row[i + 1] : 255; }
      else { out[o] = row[i]; out[o + 1] = row[i + 1]; out[o + 2] = row[i + 2]; out[o + 3] = ch === 4 ? row[i + 3] : 255; }
    }
    [prev, row] = [row, prev];
  }
  return {width, height, data: out};
}
const table = new Int32Array(256).map((_, n) => { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; return c; });
function crc(buf) { let c = -1; for (const v of buf) c = table[(c ^ v) & 255] ^ (c >>> 8); return (c ^ -1) >>> 0; }
function chunk(kind, body) { const h = Buffer.alloc(8); h.writeUInt32BE(body.length, 0); h.write(kind, 4, 'ascii'); const t = Buffer.alloc(4); t.writeUInt32BE(crc(Buffer.concat([h.subarray(4), body])), 0); return Buffer.concat([h, body, t]); }
function write(file, width, height, rgba) {
  const ihdr = Buffer.alloc(13); ihdr.writeUInt32BE(width, 0); ihdr.writeUInt32BE(height, 4); ihdr[8] = 8; ihdr[9] = 6;
  const raw = Buffer.alloc((width * 4 + 1) * height);
  for (let y = 0; y < height; y++) { raw[y * (width * 4 + 1)] = 0; Buffer.from(rgba.buffer, rgba.byteOffset + y * width * 4, width * 4).copy(raw, y * (width * 4 + 1) + 1); }
  fs.writeFileSync(file, Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk('IHDR', ihdr), chunk('IDAT', zlib.deflateSync(raw, {level: 9})), chunk('IEND', Buffer.alloc(0))]));
}
module.exports = {read, write};
