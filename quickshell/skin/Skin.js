.pragma library
// Skins (docs/SKINS.md): the pure half. Everything here is data in, data out, so it runs in the
// shell, in Node tests and in the Chromium harness alike. No QML, no canvas.
//
// A skin is skin.json plus image files and sheets. Elements are things you can see and press:
// their looks (images, sheet cells, frames chosen by shell values), active areas, animations
// and the actions they trigger. Layouts place elements on the rail and the dock; cards and
// hands add to the deck.

// ── Merging: your skin over the default, key by key ──────────────────────────────────────────
// Objects merge; arrays and values replace; null removes the key.
function merge(base, over) {
    if (over === undefined) return clone(base);
    if (!isObject(base) || !isObject(over)) return clone(over);
    var out = {}, k;
    for (k in base) if (base.hasOwnProperty(k)) out[k] = clone(base[k]);
    for (k in over) if (over.hasOwnProperty(k)) {
        if (over[k] === null) delete out[k];
        else out[k] = isObject(out[k]) && isObject(over[k]) ? merge(out[k], over[k]) : clone(over[k]);
    }
    return out;
}
function isObject(v) { return v !== null && typeof v === "object" && !Array.isArray(v); }
function clone(v) { return v === undefined ? undefined : JSON.parse(JSON.stringify(v)); }

// ── Units ─────────────────────────────────────────────────────────────────────────────────────
// Sizes and points are in the element's units: "mm" (life size, scaled by the output's px/mm)
// or "px" (logical px). The skin sets a default; an element may override.
function unitsOf(manifest, element) { return (element && element.units) || (manifest && manifest.units) || "mm"; }
function scaleFor(units, pxmm) { return units === "px" ? 1 : pxmm; }

// ── Images and sheets ─────────────────────────────────────────────────────────────────────────
// images: { name: "file.png" | {file} | {sheet, rect: [x, y, w, h]} | {sheet, grid: [w, h],
//           start?: n, count: n} (a run of cells: a frame list) | [name, …] (a frame list) }
// sheets: { name: {file, columns?} }: cells are counted left to right, top to bottom.
// A resolved image is {file, rect|null}; a frame list is an array of them.
function image(manifest, name) {
    var list = frames(manifest, name);
    return list.length ? list[0] : null;
}
function frames(manifest, name, depth) {
    if (!name || (depth || 0) > 8) return [];
    if (Array.isArray(name)) {
        var all = [];
        for (var i = 0; i < name.length; i++) all = all.concat(frames(manifest, name[i], (depth || 0) + 1));
        return all;
    }
    var images = (manifest && manifest.images) || {}, sheets = (manifest && manifest.sheets) || {}, d = images[name];
    if (d === undefined) return /\.(png|jpe?g|webp)$/i.test(name) ? [{file: name, rect: null}] : [];
    if (typeof d === "string") return /\.(png|jpe?g|webp)$/i.test(d) ? [{file: d, rect: null}] : frames(manifest, d, (depth || 0) + 1);
    if (Array.isArray(d)) return frames(manifest, d, (depth || 0) + 1);
    if (d.file) return [{file: d.file, rect: d.rect || null}];
    var sheet = sheets[d.sheet];
    if (!sheet || !sheet.file) return [];
    if (d.rect) return [{file: sheet.file, rect: d.rect}];
    if (d.grid) {
        var cw = d.grid[0], ch = d.grid[1], cols = sheet.columns || d.columns || 1, start = d.start || 0, count = d.count || 1, out = [];
        for (var c = 0; c < count; c++) { var n = start + c; out.push({file: sheet.file, rect: [(n % cols) * cw, Math.floor(n / cols) * ch, cw, ch]}); }
        return out;
    }
    return [];
}
// Every distinct file an element (with its regions, states, frames and animations) needs.
function files(manifest, element) {
    var names = [];
    function add(n) { if (n) names.push(n); }
    function look(l) { if (!l) return; add(l.image); add(l.frames && l.frames.images); add(l.mask); add(l.overlay); }
    look(element);
    (element.states || []).forEach(look);
    var anims = element.animations || {};
    for (var e in anims) (Array.isArray(anims[e]) ? anims[e] : [anims[e]]).forEach(function (a) { if (a && a.frames) add(a.frames); });
    (element.regions || []).forEach(function (r) { look(r); (r.states || []).forEach(look); if (r.hit) [].concat(r.hit).forEach(function (h) { if (h && h.mask) add(h.mask); }); });
    [].concat(element.hit || []).forEach(function (h) { if (h && h.mask) add(h.mask); });
    var seen = {}, out = [];
    names.forEach(function (n) { frames(manifest, n).forEach(function (f) { if (!seen[f.file]) { seen[f.file] = true; out.push(f.file); } }); });
    return out;
}

// ── Shell values and conditions ───────────────────────────────────────────────────────────────
// state is a flat object of shell values ("volume": 0.62, "battery.state": "chg", …).
function value(state, source) { return state ? state[source] : undefined; }
// when: {source, eq | ne | lt | lte | gt | gte | in: [..] | truthy: true|false} | {all: [..]} |
// {any: [..]} | {not: {..}}. A missing `when` is always true.
function test(when, state) {
    if (!when) return true;
    if (when.all) { for (var i = 0; i < when.all.length; i++) if (!test(when.all[i], state)) return false; return true; }
    if (when.any) { for (var j = 0; j < when.any.length; j++) if (test(when.any[j], state)) return true; return false; }
    if (when.not) return !test(when.not, state);
    var v = value(state, when.source);
    if ("eq" in when) return v === when.eq;
    if ("ne" in when) return v !== when.ne;
    if ("lt" in when) return v < when.lt;
    if ("lte" in when) return v <= when.lte;
    if ("gt" in when) return v > when.gt;
    if ("gte" in when) return v >= when.gte;
    if ("in" in when) return Array.isArray(when.in) && when.in.indexOf(v) >= 0;
    if ("truthy" in when) return !!v === !!when.truthy;
    return !!v;
}
// The look in force: the first state whose `when` holds, laid over the element's own look.
// A look: {image | frames: {source, images, min?, max?}, ink: {mask, from, to, source, bands?},
// overlay, markers: [{at, shape: "ring"|"dot", when}]}.
function look(element, state) {
    var base = {image: element.image, frames: element.frames, ink: element.ink, overlay: element.overlay, markers: element.markers || []};
    var states = element.states || [];
    for (var i = 0; i < states.length; i++) if (test(states[i].when, state)) {
        var s = states[i], out = {};
        for (var k in base) out[k] = base[k];
        for (var k2 in s) if (k2 !== "when") out[k2] = s[k2];
        if (s.image && !s.frames) out.frames = null;
        if (s.frames && !s.image) out.image = null;
        return out;
    }
    return base;
}
// Index into a frame list for a value: frames {source, min = 0, max = 1}, nearest of n.
function frameIndex(spec, n, state) {
    if (!spec || n <= 1) return 0;
    var v = Number(value(state, spec.source)), lo = spec.min === undefined ? 0 : spec.min, hi = spec.max === undefined ? 1 : spec.max;
    if (!isFinite(v)) return 0;
    var t = (Math.max(lo, Math.min(hi, v)) - lo) / ((hi - lo) || 1);
    return Math.max(0, Math.min(n - 1, Math.round(t * (n - 1))));
}
// Values that change a look: only these repaint the element.
function sources(element) {
    var out = [];
    function add(s) { if (s && out.indexOf(s) < 0) out.push(s); }
    function cond(w) { if (!w) return; add(w.source); (w.all || []).concat(w.any || []).forEach(cond); if (w.not) cond(w.not); }
    function look(l) { if (!l) return; cond(l.when); if (l.frames) add(l.frames.source); if (l.ink) { add(l.ink.source); if (l.ink.bands) cond(l.ink.bands); }
        (l.markers || []).forEach(function (m) { cond(m.when); }); }
    look(element); (element.states || []).forEach(look);
    (element.regions || []).forEach(function (r) { look(r); (r.states || []).forEach(look); cond(r.visibleWhen); });
    cond(element.visibleWhen);
    var anims = element.animations || {};
    for (var e in anims) if (e.indexOf("change:") === 0) add(e.slice(7));
    return out;
}

// ── Templates (tags, card text) ───────────────────────────────────────────────────────────────
// "Sound {{volume|percent}}": filters percent, int, upper, lower, plural:word.
function format(template, state) {
    return String(template || "").replace(/\{\{\s*([\w.]+)\s*(?:\|\s*([\w:]+))?\s*\}\}/g, function (m, source, filter) {
        var v = value(state, source);
        if (v === undefined || v === null) return "";
        if (!filter) return String(v);
        if (filter === "percent") return Math.round(Number(v) * 100) + "%";
        if (filter === "int") return String(Math.round(Number(v)));
        if (filter === "upper") return String(v).toUpperCase();
        if (filter === "lower") return String(v).toLowerCase();
        if (filter.indexOf("plural:") === 0) return Number(v) === 1 ? filter.slice(7) : filter.slice(7) + "s";
        return String(v);
    });
}

// ── Animations ────────────────────────────────────────────────────────────────────────────────
// frames: {frames: imageName, fps = 12, mode: once | hold | loop | pingpong}
// tween:  {tween: {x, y, rotate, scale, opacity}, duration = 150, easing: linear | inOutQuad |
//          outCubic | outBack}: moves the element's pose to these values (from where it is).
// Events: hoverIn, hoverOut, press, release, click, load, change:<source>.
function animationsFor(element, event) {
    var a = (element.animations || {})[event];
    return !a ? [] : Array.isArray(a) ? a : [a];
}
// Frame index at time t (ms) of a frames animation over n frames; -1 once it has ended (once).
function frameAt(anim, n, t) {
    if (n <= 0) return -1;
    var fps = anim.fps || 12, step = Math.floor(t * fps / 1000), mode = anim.mode || "once";
    if (mode === "loop") return step % n;
    if (mode === "pingpong") { var p = n > 1 ? step % (2 * n - 2) : 0; return p < n ? p : 2 * n - 2 - p; }
    if (step < n) return step;
    return mode === "hold" ? n - 1 : -1;
}
var EASE = {
    linear: function (t) { return t; },
    inOutQuad: function (t) { return t < 0.5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2; },
    outCubic: function (t) { return 1 - Math.pow(1 - t, 3); },
    outBack: function (t) { var c = 1.70158; return 1 + (c + 1) * Math.pow(t - 1, 3) + c * Math.pow(t - 1, 2); }
};
var IDENTITY = {x: 0, y: 0, rotate: 0, scale: 1, opacity: 1};
function pose(p) { var o = {}; for (var k in IDENTITY) o[k] = p && p[k] !== undefined ? p[k] : IDENTITY[k]; return o; }
// Pose between `from` and the tween's target at time t (ms).
function tweenAt(from, anim, t) {
    var to = pose(anim.tween), f = pose(from), d = anim.duration === undefined ? 150 : anim.duration;
    var e = (EASE[anim.easing] || EASE.outCubic)(d <= 0 ? 1 : Math.max(0, Math.min(1, t / d))), out = {};
    for (var k in IDENTITY) out[k] = f[k] + (to[k] - f[k]) * e;
    return out;
}

// ── Active areas ──────────────────────────────────────────────────────────────────────────────
// hit: one shape or a list; a point inside any counts. In element units:
//   {rect: [x, y, w, h]}, {circle: [cx, cy, r]}, {polygon: [[x, y], …]}, {alpha: true} (the
//   drawn look's own pixels), {mask: imageName} (opaque pixels of a mask over the element box).
// alpha and mask are looked up by the caller (alphaAt(kind, x, y)), since they are pixel data.
function inShape(shape, x, y, alphaAt) {
    if (shape.rect) { var r = shape.rect; return x >= r[0] && y >= r[1] && x <= r[0] + r[2] && y <= r[1] + r[3]; }
    if (shape.circle) { var c = shape.circle; return (x - c[0]) * (x - c[0]) + (y - c[1]) * (y - c[1]) <= c[2] * c[2]; }
    if (shape.polygon) return inPolygon(shape.polygon, x, y);
    if (shape.alpha) return !!(alphaAt && alphaAt("alpha", x, y));
    if (shape.mask) return !!(alphaAt && alphaAt("mask:" + shape.mask, x, y));
    return false;
}
function inPolygon(p, x, y) {
    var inside = false;
    for (var i = 0, j = p.length - 1; i < p.length; j = i++) {
        if ((p[i][1] > y) !== (p[j][1] > y) && x < (p[j][0] - p[i][0]) * (y - p[i][1]) / ((p[j][1] - p[i][1]) || 1e-9) + p[i][0]) inside = !inside;
    }
    return inside;
}
// What a point hits: the topmost live region (last listed is on top), else the element itself
// ("" when the element has no hit of its own and the point misses its alpha). alphaAt(kind, x,
// y, regionId) answers alpha/mask lookups; live(regionOrElement) says whether it is active.
function hit(element, x, y, alphaAt, live) {
    var regions = element.regions || [];
    for (var i = regions.length - 1; i >= 0; i--) {
        var r = regions[i];
        if (live && !live(r)) continue;
        var shapes = [].concat(r.hit || (r.rect ? [{rect: r.rect}] : [{alpha: true}]));
        for (var s = 0; s < shapes.length; s++) if (inShape(shapes[s], x, y, function (k, px, py) { return alphaAt(k, px, py, r.id); })) return r.id;
    }
    var own = [].concat(element.hit || [{alpha: true}]);
    for (var o = 0; o < own.length; o++) if (inShape(own[o], x, y, function (k, px, py) { return alphaAt(k, px, py, ""); })) return "#";
    return "";
}

// ── Actions ───────────────────────────────────────────────────────────────────────────────────
// "name" or "name:argument". The registry (skin/Actions.qml) runs them; commands are only the
// names defined in config.toml [commands.custom], never argv from a skin.
var ACTIONS = ["none", "launcher", "deal", "sheet", "notifications", "history", "clipboard", "tray", "mute", "volume", "brightness",
               "microphone", "workspace", "minimize", "lock", "media", "dnd", "hide", "command"];
function parseAction(s) {
    if (typeof s !== "string" || !s) return null;
    var i = s.indexOf(":"), name = i < 0 ? s : s.slice(0, i), arg = i < 0 ? "" : s.slice(i + 1);
    return ACTIONS.indexOf(name) < 0 ? null : {name: name, arg: arg};
}
var TRIGGERS = ["click", "rightClick", "middleClick", "doubleClick", "scrollUp", "scrollDown"];

// ── Validation ────────────────────────────────────────────────────────────────────────────────
// Problems an author should see (doctor, logs). Never throws; the shell drops what is invalid.
function check(manifest) {
    var errors = [], m = manifest || {};
    function err(path, text) { errors.push(path + ": " + text); }
    if (m.units && m.units !== "mm" && m.units !== "px") err("units", "mm or px");
    var els = m.elements || {};
    for (var id in els) {
        var e = els[id], p = "elements." + id;
        if (!isObject(e)) { err(p, "must be an object"); continue; }
        if (!(e.size && e.size.length === 2 && e.size[0] > 0 && e.size[1] > 0)) err(p + ".size", "[width, height] required");
        if (!e.image && !(e.frames && e.frames.images) && !(e.states && e.states.length)) err(p, "needs image, frames or states");
        if (e.image && !image(m, e.image)) err(p + ".image", "unknown image " + JSON.stringify(e.image));
        var trig = e.triggers || {};
        for (var t in trig) { if (TRIGGERS.indexOf(t) < 0) err(p + ".triggers." + t, "unknown trigger"); else if (!parseAction(trig[t])) err(p + ".triggers." + t, "unknown action " + JSON.stringify(trig[t])); }
        (e.regions || []).forEach(function (r, i) {
            if (!r.id) err(p + ".regions[" + i + "]", "id required");
            var rt = r.triggers || {};
            for (var t2 in rt) if (!parseAction(rt[t2])) err(p + ".regions[" + i + "].triggers." + t2, "unknown action " + JSON.stringify(rt[t2]));
        });
        if (e.ink && !(e.ink.mask && e.ink.from && e.ink.to && e.ink.source)) err(p + ".ink", "mask, from, to and source required");
    }
    var items = (m.rail && m.rail.items) || [];
    items.forEach(function (it, i) { if (it.element && !els[it.element]) err("rail.items[" + i + "]", "unknown element " + it.element); });
    ["before", "after"].forEach(function (side) { ((m.dock && m.dock[side]) || []).forEach(function (it, i) { if (!els[it.element || it]) err("dock." + side + "[" + i + "]", "unknown element"); }); });
    var cards = m.cards || {};
    for (var c in cards) { if (!cards[c].face || !els[cards[c].face]) err("cards." + c + ".face", "an element id is required"); }
    return errors;
}

// ── Files: relative to the skin they came from ────────────────────────────────────────────────
// Before two skins are merged, every image file is made absolute against its own folder
// (base: "file:///…/skin/"), so a merged skin can mix your files with the default's.
var FILE = /\.(png|jpe?g|webp)$/i;
function absolutise(manifest, base) {
    var m = clone(manifest || {});
    function abs(f) { return typeof f === "string" && FILE.test(f) && !/^[a-z]+:\/\//i.test(f) && f.charAt(0) !== "/" ? base + f : f.charAt && f.charAt(0) === "/" ? "file://" + f : f; }
    function walk(v) {
        if (Array.isArray(v)) return v.map(walk);
        if (isObject(v)) { var o = {}; for (var k in v) o[k] = walk(v[k]); return o; }
        return typeof v === "string" && FILE.test(v) ? abs(v) : v;
    }
    return walk(m);
}
