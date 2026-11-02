.pragma library
.import "DeviceGeometry.js" as Geo
.import "Noise.js" as Noise
.import "Pixels.js" as Pixels
// Removable-media objects (SURFACES.md §2a): life-size skin images of devices, posed on the
// rail and quantised through the ordered dither at the logical-pixel grain.
//
// The images must be loaded in the canvas (imageUrls). Shadows and the wax seal are composited
// here in JavaScript from getImageData passes, so one Canvas does everything.
//
// Device-local units: each device is drawn leading end at x = 0, extending to −L, centred on
// y = 0 (sideways devices: top end along the rail). `real` mm map to `drawn` units.

var IMAGES = {}, SEAL = {seal: "", cracked: ""};
function drawImage(ctx, url, r) { if (url) ctx.drawImage(url, r[0], r[1], r[2], r[3]); }
// Images in force: {kind: {device: url, envelope: url}}, seal: {seal: url, cracked: url}.
function setImages(images, seal) { IMAGES = images || {}; SEAL = seal || {seal: "", cracked: ""}; }
function imageUrls(kind) { var i = IMAGES[kind] || {}, out = []; if (i.device) out.push(i.device); if (i.envelope) out.push(i.envelope); if (SEAL.seal) out.push(SEAL.seal); if (SEAL.cracked) out.push(SEAL.cracked); return out; }
// Encrypted (LUKS): the device in a manila envelope (or a disc in a sleeve), sealed with wax;
// both are skin images. The seal is 26 logical px across, centred on sealAt.
function envelope(c, dv, kind) { drawImage(c, (IMAGES[kind] || {}).envelope, Geo.envelopeRect(dv)); }
function seal(c, x, y, cracked) { drawImage(c, cracked ? SEAL.cracked || SEAL.seal : SEAL.seal, [x - 13, y - 13, 26, 26]); }

// Bake one device into the canvas: contact shadow (blurred, dithered to on/off at 42 %),
// the painted device quantised to seven levels per channel, then the envelope's seal.
// o: {kind, pose, cy, pxmm, rail, compact, outX, locked, cracked, D, gc, W, H (device px), sealAt: [x, y]}
function bake(ctx, o) {
    var dv = Geo.device(o.kind), D = o.D || 1, gc = o.gc || 1, W = o.W, H = o.H, url = ((!o.builtin && IMAGES[o.kind]) || IMAGES.ssd || {}).device;
    var shapeOf = function () { drawImage(ctx, url, Geo.rect(dv)); };
    function begin() { ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.clearRect(0, 0, W, H); ctx.save(); ctx.scale(D, D); }
    function posed() { Geo.transform(ctx, dv, o.pose, o.cy, o.pxmm, o.rail, o.compact, o.outX); }
    // 1. shadow silhouette, 3 logical px down-right
    begin(); ctx.translate(3, 4); posed(); shapeOf(); ctx.restore();
    var shadow = Pixels.blurAlpha(ctx.getImageData(0, 0, W, H).data, W, H, 3 * D);
    // 2. the device (and envelope)
    begin(); posed(); shapeOf(); if (o.locked) envelope(ctx, dv, o.kind); ctx.restore();
    var art = ctx.getImageData(0, 0, W, H), px = art.data;
    Pixels.quantise(px, W, H, 7, gc);
    // 3. wax seal
    var sealPx = null, sealShadow = null;
    if (o.locked && o.sealAt) {
        begin(); seal(ctx, o.sealAt[0], o.sealAt[1], o.cracked); ctx.restore();
        var sd = ctx.getImageData(0, 0, W, H); sealPx = sd.data; Pixels.quantise(sealPx, W, H, 7, gc);
        sealShadow = Pixels.blurAlpha(sealPx, W, H, 1.5 * D);
    }
    var out = ctx.createImageData(W, H), q = out.data, sdx = Math.round(1.5 * D), sdy = Math.round(2 * D);
    for (var y = 0; y < H; y++) for (var x = 0; x < W; x++) {
        var i = (y * W + x) * 4, j = y * W + x;
        if (shadow[j] / 255 * 0.42 > Noise.thrPx(x, y, gc)) Pixels.put(q, i, 0, 0, 0, 107);   // 42 % shadow, dithered on/off
        if (px[i + 3]) Pixels.put(q, i, px[i], px[i + 1], px[i + 2], 255);
        if (sealPx) {
            var sx = x - sdx, sy = y - sdy;
            if (sx >= 0 && sy >= 0) { var ss = sealShadow[sy * W + sx] / 255 * 0.45; if (ss > 0) Pixels.over(q, i, 0, 0, 0, ss); }
            if (sealPx[i + 3]) Pixels.put(q, i, sealPx[i], sealPx[i + 1], sealPx[i + 2], 255);
        }
    }
    ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.clearRect(0, 0, W, H);
    ctx.putImageData(out, 0, 0, 0, 0, W, H);
}

