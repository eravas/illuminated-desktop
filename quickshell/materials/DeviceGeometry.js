.pragma library
// Removable media geometry (SURFACES.md §2a): each kind's physical size and pose, life-size
// scale, placement on the rail, the bay it opens, and the motion between poses. No art: the
// pictures are skin images (DeviceArt.js draws them into these rects).

// Device geometry (behaviour, not art): physical width `real` mm spans `drawn` local units; the
// body runs from x = −L to 0 (leading end at 0), centred on y; discs are circles of radius R.
// The pictures come from the skin (docs/SKINS.md, "devices"); setImages() attaches them.
var DEVICES = {
    usb: {"name": "USB stick", "real": 18, "drawn": 22, "L": 67},
    sd: {"name": "SD card", "real": 24, "drawn": 32, "L": 43},
    disc: {"name": "Disc", "disc": true, "R": 120, "rim": 46, "rimOff": 10, "real": 60, "drawn": 120},
    drive: {"name": "Drive", "real": 102, "drawn": 50, "L": 72, "fromBottom": true},
    ssd: {"name": "SSD", "real": 22, "drawn": 22, "L": 80},
    android: {"name": "Phone", "real": 73.3, "drawn": 50, "L": 107, "sideways": true, "fromBottom": true, "cornerPivot": true},
    iphone: {"name": "Phone", "real": 71.5, "drawn": 50, "L": 103, "sideways": true, "fromBottom": true, "cornerPivot": true},
    pico: {"name": "Board", "real": 21, "drawn": 21, "L": 51},
    esp32: {"name": "Board", "real": 28, "drawn": 28, "L": 55},
    ereader: {"name": "E-reader", "real": 112, "drawn": 60, "L": 85, "fromBottom": true},
    cf: {"name": "CompactFlash card", "real": 43, "drawn": 43, "L": 36},
    ms: {"name": "Memory Stick", "real": 20, "drawn": 20, "L": 31},
    zip: {"name": "Zip disk", "real": 98, "drawn": 50, "L": 50, "sideways": true, "fromBottom": true},
    floppy: {"name": "Floppy", "real": 90, "drawn": 68, "L": 71, "sideways": true, "fromBottom": true}
};
// Local rect a device's image fills (and its envelope's, 2 units larger all round).
function rect(dv) { return dv.disc ? [-dv.R, -dv.R, 2 * dv.R, 2 * dv.R] : [-dv.L, -dv.drawn / 2, dv.L, dv.drawn]; }
function envelopeRect(dv) { var r = rect(dv); return [r[0] - 2, r[1] - 2, r[2] + 4, r[3] + 4]; }
var KINDS = Object.keys(DEVICES);

// Kinds a skin adds (docs/SKINS.md: devices.<kind> with size [length, width] mm and `like`):
// geometry copied from the built-in kind it is like, sized to its own dimensions.
var ART = {};
function registerArt(kind, spec) {
    if (!spec || !spec.size || !(spec.size[0] > 0 && spec.size[1] > 0)) { delete ART[kind]; return false; }
    var like = DEVICES[spec.like] || DEVICES[kind] || DEVICES.ssd, Lmm = spec.size[0], Wmm = spec.size[1];
    if (like.disc) like = DEVICES.ssd;
    ART[kind] = {name: spec.name || like.name, real: Wmm, drawn: Wmm, L: Lmm, sideways: !!like.sideways, fromBottom: !!like.fromBottom, cornerPivot: !!like.cornerPivot};
    return true;
}
function unregisterArt(kind) { delete ART[kind]; }
// The geometry for a kind: one the skin added, the built-in, or the SSD fallback. `version` is
// unused; pass the skin's version so QML bindings re-evaluate when the skin changes.
function device(kind, version) { return ART[kind] || DEVICES[kind] || DEVICES.ssd; }

// Life-size presets: logical px per mm (SURFACES.md §2a). "compact" is half of 24″ 1080p.
var PX_PER_MM = {"24": 1920 / 531, "27": 2560 / 597, "15.6": 1920 / 344, "14q": 2560 / 309.9 / 1.5, "14f": 1920 / 309.9 / 1.25, "compact": 0.5 * 1920 / 531};
// From an output: Quickshell reports physical density; accept px/mm or px/in.
function pxPerMm(preset, physicalDensity, dpr) {
    if (preset && preset !== "auto") return PX_PER_MM[preset] || PX_PER_MM["24"];
    var d = physicalDensity > 30 ? physicalDensity / 25.4 : physicalDensity;
    var v = d > 0 ? d / Math.max(1, dpr || 1) : 0;
    return v >= 1.5 && v <= 12 ? v : PX_PER_MM["24"];
}
function scaleOf(dv, pxmm) { return dv.real * pxmm / dv.drawn; }

// Rail geometry for placement, logical px from the rail window's left edge.
function railGeometry(railX, railWidth) {
    var x = railX === undefined ? 3 : railX, w = railWidth === undefined ? 64 : railWidth;
    return {x: x, width: w, maxX: x + w - 4, washX: x + 9, unmounted: 10, pivotMax: 170};
}
// Pose of a device: rotation th (radians, about (xR, pv) after translating the device's
// local pivot there), and the vertical extent of the part that reaches the wash (footprint).
function place(dv, mounted, pxmm, rail, compact) {
    var k = scaleOf(dv, pxmm), hh = dv.sideways ? dv.L / 2 * k : dv.drawn / 2 * k, L = dv.sideways ? dv.drawn * k : dv.L * k;
    var pivot = Math.min(L, rail.pivotMax), fb = !!dv.fromBottom, reach = rail.maxX - 1 - rail.unmounted;
    var xR = compact && mounted ? (2 * hh <= rail.width - 8 ? rail.x + rail.width / 2 + hh : rail.maxX - 1) : rail.unmounted;
    var py = fb ? (dv.cornerPivot ? 0 : L - pivot) : pivot, arm = fb ? L - py : pivot;
    var a = (fb ? -1 : 1) * (mounted && !compact ? Math.asin(Math.min(1, reach / arm)) : 0);
    var P = [[-hh, 0], [hh, 0], [hh, L], [-hh, L]].map(function (p) { var x = p[0] - hh, y = p[1] - py; return [x * Math.cos(a) - y * Math.sin(a) + xR, x * Math.sin(a) + y * Math.cos(a)]; });
    function clip(Q, X) { var o = []; for (var i = 0; i < Q.length; i++) { var A = Q[i], B = Q[(i + 1) % Q.length]; if (A[0] >= X) o.push(A); if ((A[0] >= X) !== (B[0] >= X)) { var t = (X - A[0]) / (B[0] - A[0]); o.push([X, A[1] + t * (B[1] - A[1])]); } } return o; }
    var out = clip(P, rail.washX); if (!out.length) out = clip(P, 0);
    var ys = out.map(function (p) { return p[1]; }), all = P.map(function (p) { return p[1]; });
    return {th: a, hh: hh, L: L, pv: py, xR: xR, k: k, y0: Math.min.apply(null, ys), y1: Math.max.apply(null, ys), top: Math.min.apply(null, all), bottom: Math.max.apply(null, all)};
}
// Rail space a mounted device reserves (logical px), opened above the tray.
function bay(dv, pxmm, rail, compact) {
    var k = scaleOf(dv, pxmm);
    if (dv.disc) { var R = dv.R * k, dd = Math.max(0, dv.rim - rail.washX); return Math.round(2 * Math.sqrt(Math.max(0, 2 * R * dd - dd * dd)) + 10); }
    var m = place(dv, true, pxmm, rail, compact); return Math.round(m.y1 - m.y0 + 12);
}
// Translate/rotate ctx (in logical px, already scaled by D) so device-local drawing lands in pose.
// pose: "unmounted" | "mounted" | "out" (pulled in beside a dealt card); cy: bay centre.
function transform(ctx, dv, pose, cy, pxmm, rail, compact, outX) {
    var k = scaleOf(dv, pxmm);
    if (dv.disc) {
        var x = pose === "out" ? outX : pose === "mounted" ? dv.rim : dv.rimOff;
        ctx.translate(x - dv.R * k, pose === "unmounted" ? cy - bay(dv, pxmm, rail, compact) / 2 : cy); ctx.scale(k, k); return;
    }
    var mounted = pose === "mounted", pl = place(dv, mounted, pxmm, rail, compact), m = place(dv, true, pxmm, rail, compact);
    var yB = mounted ? cy - (m.y0 + m.y1) / 2 : cy - 6 - pl.y1, xR = pose === "out" ? outX : pl.xR;
    if (pose === "out") yB = cy - (m.y0 + m.y1) / 2;
    ctx.translate(xR, yB); ctx.rotate(pose === "out" ? 0 : pl.th); ctx.translate(-pl.hh, -pl.pv);
    if (dv.sideways) { ctx.translate(pl.hh, dv.drawn / 2 * k); ctx.scale(k, k); } else { ctx.rotate(-Math.PI / 2); ctx.scale(k, k); }
}
// How far a device comes in beside its card: fully, or about the first third for large ones.
function outReach(dv, pxmm) {
    var k = scaleOf(dv, pxmm), across = dv.disc ? 2 * dv.R * k : dv.sideways ? dv.L * k : dv.drawn * k;
    return dv.disc || dv.real >= 90 ? across / 3 : across;
}

// Motion between the unmounted and mounted poses, for animating the unmounted bake with a
// QML transform: rotate by `angle` (degrees) about (originX, originY), then translate by
// (dx, dy). At rest the shell swaps to a grid-aligned bake of the new pose.
function motion(kind, cy, pxmm, rail, compact) {
    var dv = device(kind), k = scaleOf(dv, pxmm);
    if (dv.disc) { var b = bay(dv, pxmm, rail, compact); return {originX: 0, originY: 0, angle: 0, dx: dv.rim - dv.rimOff, dy: b / 2}; }
    var u = place(dv, false, pxmm, rail, compact), m = place(dv, true, pxmm, rail, compact);
    var yU = cy - 6 - u.y1, yM = cy - (m.y0 + m.y1) / 2;
    return {originX: u.xR, originY: yU, angle: (m.th - u.th) * 180 / Math.PI, dx: m.xR - u.xR, dy: yM - yU};
}
// Vertical extent (logical px) of a device in a pose, for hit areas and the input region.
function extent(kind, pose, cy, pxmm, rail, compact) {
    var dv = device(kind);
    if (dv.disc) { var R = dv.R * scaleOf(dv, pxmm), c = pose === "unmounted" ? cy - bay(dv, pxmm, rail, compact) / 2 : cy; return {top: c - R, bottom: c + R}; }
    var p = place(dv, pose === "mounted", pxmm, rail, compact), m = place(dv, true, pxmm, rail, compact);
    var yB = pose === "mounted" || pose === "out" ? cy - (m.y0 + m.y1) / 2 : cy - 6 - p.y1;
    return {top: yB + p.top, bottom: yB + p.bottom};
}
