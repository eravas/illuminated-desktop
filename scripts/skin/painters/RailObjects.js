.pragma library
.import "../Materials.js" as M
// Painters for the default skin's rail objects (scripts/skin/build-default.cjs). Not loaded by the
// shell: the shell only composites the images these write. The rail's objects (DESIGN-SYSTEM.md §3.13): small real things lying across the rail at
// life size, entering from the screen edge with their working end showing, painted and then
// quantised through the dither like the removable media. QML Context2D subset only.
//
// Coordinates for the hand objects: x = 0 at the screen edge, working end at x = E (logical px);
// y = 0 at the slot centre. k = logical px per mm.
// state: {level 0..1, stage 0..4, connecting, battery: "dis" | "chg" | "held", unread}

function lg(ctx, x0, y0, x1, y1, stops) { var g = ctx.createLinearGradient(x0, y0, x1, y1); for (var i = 0; i < stops.length; i++) g.addColorStop(stops[i][0], stops[i][1]); return g; }
// An ellipse path (QML's ellipse() takes a bounding box, the browser's a centre; avoid both).
function oval(ctx, cx, cy, rx, ry) { ctx.save(); ctx.translate(cx, cy); ctx.scale(rx, ry); ctx.beginPath(); ctx.arc(0, 0, 1, 0, Math.PI * 2, false); ctx.restore(); }

// Slot depth of each object in mm (its extent along the rail); slot height = depth × k + 10.
// The converter lies at an angle, so its depth follows the rail's width (E).
var DEPTH = {launcher: 8, levels: 8, connections: 12, battery: 22, power: 12};
var CONVERTER_ANGLE = 52 * Math.PI / 180;       // from horizontal; the mouth up and to the right
var CONVERTER_HALF = 3.6;                  // mm, the reservoir's half-width
var CONVERTER_RESERVOIR = [3.3, 22.5];     // mm along the axis from the mouth tip
function converterSpan(k, E) {
    var t = CONVERTER_ANGLE, xm = E - 1.6 * k;
    return {xm: xm, top: 2 * k, drop: xm * Math.tan(t) + CONVERTER_HALF * k / Math.cos(t)};
}
function slotHeight(kind, k, E, spec) {
    if (spec && spec.size) return Math.round(Math.min(spec.depth || spec.size[1], 30) * k + 10);
    if (kind === "battery" && E > 0) { var sp = converterSpan(k, E); return Math.round(Math.min(sp.top + sp.drop, 30 * k) + 10); }
    return Math.round((DEPTH[kind] || 8) * k + 10);
}
// Iron-gall ink, freshly written (blue-black); the vial and the converter both hold it.
var IRON_GALL = ["#151C30", "#24304F", "#3A4C78", "#6A7EA8"];

// ── Launcher: a fountain pen seen from above (unbranded) ──
// Steel slip-on nib with a gold centre band and gold tip, after the pen it is modelled on: a
// parallel back with a slanted rear edge where it sits on the section, then a straight taper
// to the tipping. No breather hole. The grey section continues off the screen edge.
function nib(c, k, E) {
    var m = function (v) { return v * k; }, tip = E - m(0.3), L = m(13), b = tip - L, w = m(2.9);
    // Section, its moulded flat facing up.
    c.fillStyle = lg(c, 0, -m(4.6), 0, m(4.6), [[0, "#8B9095"], [0.35, "#6C7176"], [0.75, "#50545A"], [1, "#3B3E42"]]);
    c.beginPath(); c.moveTo(-20, -m(4.6)); c.lineTo(b + m(0.6), -m(4.6)); c.quadraticCurveTo(b + m(2.4), -m(4.4), b + m(2.4), -m(3.3));
    c.lineTo(b + m(2.4), m(3.3)); c.quadraticCurveTo(b + m(2.4), m(4.4), b + m(0.6), m(4.6)); c.lineTo(-20, m(4.6)); c.closePath(); c.fill();
    c.fillStyle = "rgba(255,255,255,0.13)"; c.fillRect(-20, -m(1.6), b + 20, m(3.2));
    c.fillStyle = "rgba(0,0,0,0.28)"; c.fillRect(-20, -m(1.6), b + 20, Math.max(1, m(0.15)));
    // Feed, a dark edge either side of the nib's parallel back.
    c.fillStyle = "#1E1F22"; c.fillRect(b + m(2), -w - m(0.35), m(4.2), 2 * w + m(0.7));
    // Nib outline: slanted rear edge, parallel back, straight taper, rounded tip.
    var back = b + m(5.6);
    function outline() {
        c.beginPath();
        c.moveTo(b + m(1.2), -w); c.lineTo(back, -w);
        c.lineTo(tip - m(0.9), -m(0.55)); c.quadraticCurveTo(tip, -m(0.3), tip, 0); c.quadraticCurveTo(tip, m(0.3), tip - m(0.9), m(0.55));
        c.lineTo(back, w); c.lineTo(b + m(3.0), w); c.closePath();
    }
    outline(); c.fillStyle = lg(c, 0, -w, 0, w, [[0, "#9A9FA6"], [0.22, "#E4E8EC"], [0.42, "#FFFFFF"], [0.62, "#D6DADF"], [1, "#8D9299"]]); c.fill();
    c.save(); outline(); c.clip();
    // Gold centre band from the rear edge to the tip, narrowing with the taper.
    c.fillStyle = lg(c, 0, -m(0.9), 0, m(0.9), [[0, "#B8862E"], [0.4, "#F2CC72"], [0.6, "#FFE3A0"], [1, "#B07D24"]]);
    c.beginPath(); c.moveTo(b + m(2.0), -m(0.95)); c.lineTo(back, -m(0.85)); c.lineTo(tip, -m(0.2)); c.lineTo(tip, m(0.2)); c.lineTo(back, m(0.85)); c.lineTo(b + m(2.4), m(0.95)); c.closePath(); c.fill();
    c.fillStyle = "rgba(255,255,255,0.45)"; c.fillRect(b, -w + m(0.6), back - b, Math.max(1, m(0.25)));   // polish along the steel
    c.restore();
    c.strokeStyle = "rgba(70,74,80,0.85)"; c.lineWidth = Math.max(0.7, m(0.13)); outline(); c.stroke();
    c.strokeStyle = "#4A3510"; c.lineWidth = Math.max(0.8, m(0.15)); c.beginPath(); c.moveTo(back + m(1.4), 0); c.lineTo(tip - m(0.25), 0); c.stroke();   // slit
    c.fillStyle = "#C9A65A"; oval(c, tip - m(0.35), 0, m(0.45), m(0.5)); c.fill();                    // gold tipping
}

// ── Levels: glass vial of iron-gall ink, the ink at the volume level (height of the meniscus) ──
function vial(c, k, E, s) {
    var m = function (v) { return v * k; }, r = m(3.6), x1 = E - r, lv = Math.max(0, Math.min(1, s.level || 0));
    function body() { c.beginPath(); c.moveTo(-20, -r); c.lineTo(x1, -r); c.arc(x1, 0, r, -Math.PI / 2, Math.PI / 2, false); c.lineTo(-20, r); c.closePath(); }
    c.save(); body(); c.clip();
    c.fillStyle = "rgba(210,225,232,0.55)"; c.fillRect(-20, -r, E + 20, 2 * r);
    var ly = r - 2 * r * lv;
    c.fillStyle = lg(c, 0, ly, 0, r, [[0, IRON_GALL[2]], [0.3, IRON_GALL[1]], [1, IRON_GALL[0]]]); c.fillRect(-20, ly, E + 20, r - ly);
    c.fillStyle = "rgba(200,215,240,0.7)"; c.fillRect(-20, ly - 0.5, E + 20, Math.max(1, m(0.25)));   // meniscus
    c.restore();
    c.strokeStyle = "rgba(120,140,150,0.85)"; c.lineWidth = Math.max(1, m(0.3)); body(); c.stroke();
    c.fillStyle = "rgba(255,255,255,0.75)"; c.fillRect(-20, -r + m(1), x1 + 12, Math.max(1, m(0.5)));
    c.fillStyle = "#8C6A45"; c.fillRect(-20, -r + m(0.4), Math.min(14, E * 0.2), 2 * r - m(0.8));    // cork, at the edge
}

// ── Connections: the end of a telescopic antenna; stylised waves for the signal stage ──
function antenna(c, k, E, s, ink) {
    var m = function (v) { return v * k; }, R = m(1.6), tip = E - m(8.6), stage = s.stage || 0;
    var sections = [[-20, m(1.5)], [tip - m(26), m(1.15)], [tip - m(11), m(0.85)]];
    for (var i = 0; i < sections.length; i++) {
        var x0 = sections[i][0], h = sections[i][1], x1 = i + 1 < sections.length ? sections[i + 1][0] + m(1.2) : tip;
        c.fillStyle = lg(c, 0, -h, 0, h, [[0, "#F2F4F6"], [0.35, "#C3C8CE"], [0.7, "#868C93"], [1, "#5C6168"]]); c.fillRect(x0, -h, x1 - x0, 2 * h);
        if (i > 0) { c.fillStyle = "rgba(0,0,0,0.35)"; c.fillRect(x0, -h, Math.max(1, m(0.25)), 2 * h); }
    }
    c.fillStyle = lg(c, tip - R, -R, tip + R, R, [[0, "#FFFFFF"], [0.4, "#C9CED4"], [1, "#666B72"]]);
    c.beginPath(); c.arc(tip, 0, R, 0, Math.PI * 2, false); c.fill();
    // One wave per signal stage, in ink, opening away from the screen edge; the first dashed while connecting.
    c.lineCap = "round"; c.lineWidth = Math.max(1.2, m(0.4)); c.strokeStyle = ink || "#211C15";
    var span = 0.8;
    for (var j = 1; j <= 4; j++) {
        if (j > stage && !(j === 1 && s.connecting)) continue;
        if (j === 1 && s.connecting && stage === 0) c.setLineDash([m(0.7), m(0.7)]);
        c.beginPath(); c.arc(tip, 0, R + m(1.75) * j, -span, span, false); c.stroke();
        c.setLineDash([]);
    }
}

// ── Battery: a piston converter (after the Lamy kind; unbranded), iron-gall ink = charge ──
// It lies at CONVERTER_ANGLE with the mouth up and right, so the whole reservoir is on screen at
// life size. Along the axis from the mouth tip: clear nozzle, clear reservoir (ink from the mouth
// back to the piston seal), black ring, brushed steel sleeve, black knob (off screen).
// Charging: canary bands over the ink. Plugged in but held: a canary collar on the nozzle.
function converter(c, k, E, s) {
    var m = function (v) { return v * k; }, sp = converterSpan(k, E), lv = Math.max(0, Math.min(1, s.level || 0));
    var y0 = -(sp.top + sp.drop) / 2 + sp.top, hw = m(CONVERTER_HALF), r0 = m(CONVERTER_RESERVOIR[0]), r1 = m(CONVERTER_RESERVOIR[1]);
    c.save();
    c.translate(sp.xm, y0); c.rotate(Math.PI - CONVERTER_ANGLE);      // +x runs from the mouth toward the knob
    var glass = "rgba(214,228,236,0.55)", edge = "rgba(110,125,135,0.9)";
    // Knob and collar, then the steel sleeve.
    c.fillStyle = lg(c, 0, -m(3.2), 0, m(3.2), [[0, "#4A4C50"], [0.4, "#2A2B2E"], [1, "#121314"]]); c.fillRect(r1 + m(12), -m(3.2), m(20), m(6.4));
    c.fillStyle = "rgba(255,255,255,0.12)"; c.fillRect(r1 + m(12), -m(1.2), m(20), m(2.4));
    c.fillStyle = "#151619"; c.fillRect(r1 + m(10.5), -m(3.5), m(1.5), m(7));
    c.fillStyle = lg(c, 0, -m(3.8), 0, m(3.8), [[0, "#8E9399"], [0.3, "#E2E5E8"], [0.5, "#FFFFFF"], [0.72, "#C9CDD2"], [1, "#7E838A"]]); c.fillRect(r1 + m(0.8), -m(3.8), m(9.7), m(7.6));
    c.fillStyle = "rgba(0,0,0,0.08)"; for (var bi = 0; bi < 9; bi++) c.fillRect(r1 + m(0.8), -m(3.4) + bi * m(0.85), m(9.7), Math.max(0.5, m(0.12)));   // brushed
    c.fillStyle = "#1B1C1F"; c.fillRect(r1, -m(3.7), m(0.8), m(7.4));                                 // black ring
    // Reservoir.
    c.fillStyle = glass; c.fillRect(r0, -hw, r1 - r0, 2 * hw);
    var inkEnd = r0 + (r1 - r0 - m(1.8)) * lv;                                                   // the seal's front face
    if (!s.bare) { c.fillStyle = "rgba(45,48,54,0.7)"; c.fillRect(inkEnd + m(1.8), -m(1.1), r1 - inkEnd - m(1.8), m(2.2)); }   // piston rod (bare: art template)
    if (lv > 0) {
        c.fillStyle = lg(c, 0, -hw, 0, hw, [[0, IRON_GALL[2]], [0.4, IRON_GALL[1]], [1, IRON_GALL[0]]]); c.fillRect(r0, -hw, inkEnd - r0, 2 * hw);
        if (s.battery === "chg") {
            c.save(); c.beginPath(); c.rect(r0, -hw, inkEnd - r0, 2 * hw); c.clip();
            c.fillStyle = "rgba(250,219,44,0.95)";
            for (var x = r0 - 2 * hw; x < inkEnd + 2 * hw; x += m(4)) { c.beginPath(); c.moveTo(x, -hw); c.lineTo(x + m(1.8), -hw); c.lineTo(x + m(1.8) - 2 * hw, hw); c.lineTo(x - 2 * hw, hw); c.closePath(); c.fill(); }
            c.restore();
        }
    }
    if (!s.bare) { c.fillStyle = lg(c, 0, -hw, 0, hw, [[0, "#3A3C40"], [0.5, "#16171A"], [1, "#2A2B2E"]]);       // piston seal
                   c.fillRect(inkEnd, -hw + m(0.2), m(1.8), 2 * hw - m(0.4)); }
    c.fillStyle = "rgba(255,255,255,0.65)"; c.fillRect(r0, -hw + m(0.8), r1 - r0, Math.max(1, m(0.4)));   // glint
    c.strokeStyle = edge; c.lineWidth = Math.max(1, m(0.22)); c.strokeRect(r0, -hw, r1 - r0, 2 * hw);
    // Shoulder and nozzle, clear; the bore holds ink when there is any.
    c.fillStyle = glass;
    c.beginPath(); c.moveTo(r0, -hw); c.lineTo(m(2.5), -m(1.9)); c.lineTo(0, -m(1.9)); c.lineTo(0, m(1.9)); c.lineTo(m(2.5), m(1.9)); c.lineTo(r0, hw); c.closePath(); c.fill();
    c.strokeStyle = edge; c.stroke();
    c.fillStyle = lv > 0 ? IRON_GALL[1] : "rgba(110,115,120,0.6)"; c.fillRect(0, -m(0.7), r0, m(1.4));
    c.fillStyle = "rgba(90,95,100,0.7)"; c.fillRect(m(1.0), -m(1.9), m(0.5), m(3.8));                // the nozzle's inner step
    if (s.battery === "held") { c.fillStyle = "#FADB2C"; c.fillRect(m(0.4), -m(2.15), m(1.6), m(4.3)); c.strokeStyle = "#8A7400"; c.lineWidth = 1; c.strokeRect(m(0.4), -m(2.15), m(1.6), m(4.3)); }
    c.restore();
}

// ── Power: an open matchbox, side on ──
function matchbox(c, k, E) {
    var m = function (v) { return v * k; }, h = m(5.6), bx = E - m(10);
    c.fillStyle = lg(c, 0, -h, 0, h, [[0, "#E7D7B4"], [1, "#C9B58C"]]); c.fillRect(-20, -h, bx + 20, 2 * h);
    c.fillStyle = "#4A3F38"; c.fillRect(-20, -h + m(2.2), bx + 20, m(5));
    for (var x = -18; x < bx; x += 2) { c.fillStyle = M.h2(x, 3) > 0.5 ? "#5C5048" : "#3E352F"; c.fillRect(x, -h + m(2.2), 1, m(5)); }
    c.fillStyle = "#A23B2A"; c.fillRect(bx - m(9), -h + m(0.6), m(7), m(1));                     // a printed band, no wordmark
    c.fillStyle = lg(c, 0, -h, 0, h, [[0, "#D9C7A0"], [1, "#BCA77E"]]); c.fillRect(bx, -h + m(1.2), m(7), 2 * h - m(1.2));
    c.strokeStyle = "rgba(90,70,40,0.6)"; c.lineWidth = 1; c.strokeRect(bx + 0.5, -h + m(1.2) + 0.5, m(7) - 1, 2 * h - m(1.2) - 1);
    for (var i = 0; i < 4; i++) {
        var y = -h + m(2.4) + i * m(2.4), x2 = E - m(1.2) - (i % 2) * m(0.6);
        c.fillStyle = "#E9D3A6"; c.fillRect(bx + m(1), y - m(0.6), x2 - bx - m(1), m(1.2));
        c.fillStyle = lg(c, x2 - m(1), y - m(1.2), x2 + m(1.4), y + m(1.2), [[0, "#B5452C"], [1, "#6E2216"]]); oval(c, x2, y, m(1.5), m(1.1)); c.fill();
    }
    c.strokeStyle = "rgba(60,45,25,0.55)"; c.strokeRect(-20, -h + 0.5, bx + 19.5, 2 * h - 1);
}

function draw(c, kind, k, E, s, ink) {
    if (kind === "launcher") nib(c, k, E);
    else if (kind === "levels") vial(c, k, E, s);
    else if (kind === "connections") antenna(c, k, E, s, ink);
    else if (kind === "battery") converter(c, k, E, s);
    else if (kind === "power") matchbox(c, k, E);
}

// ── Correspondence: a sheet's folded corner peeking in from the bottom-left, with a paperclip ──
// Paper hit → notifications; on or near the clip → clipboard. Geometry in the canvas's logical
// px; the canvas's bottom-left is the screen's bottom-left corner. The corner points up and right
// (beta above horizontal); the sheet's edges leave it along A (towards the screen edge) and B (down).
function paperGeometry(W, H, k, clip) {
    var beta = 62 * Math.PI / 180, back = Math.atan2(Math.sin(beta), -Math.cos(beta));
    var A = [Math.cos(back + Math.PI / 4), Math.sin(back + Math.PI / 4)], B = [Math.cos(back - Math.PI / 4), Math.sin(back - Math.PI / 4)];
    var C = [W * 0.7, H * 0.3], fold = 5.5 * k, along = 9 * k;
    return {C: C, A: A, B: B, fold: fold, k: k, clipped: clip !== false,
            clip: [C[0] + A[0] * along + B[0] * 2.4 * k, C[1] + A[1] * along + B[1] * 2.4 * k], clipRadius: Math.max(14, 5.5 * k)};
}
function local(g, x, y) { var dx = x - g.C[0], dy = y - g.C[1]; return [dx * g.A[0] + dy * g.A[1], dx * g.B[0] + dy * g.B[1]]; }
function onPaper(g, x, y) { var p = local(g, x, y); return p[0] >= 0 && p[1] >= 0 && p[0] + p[1] >= g.fold; }
function onClip(g, x, y) { return g.clipped && Math.sqrt((x - g.clip[0]) * (x - g.clip[0]) + (y - g.clip[1]) * (y - g.clip[1])) <= g.clipRadius; }
// "clipboard" | "notifications" | "" for a point in the canvas.
function hit(g, x, y) { return onClip(g, x, y) ? "clipboard" : onPaper(g, x, y) ? "notifications" : ""; }

function paper(c, W, H, k, s, ink, clip) {
    var g = paperGeometry(W, H, k, clip), C = g.C, A = g.A, B = g.B, f = g.fold, L = 600;
    function at(u, v) { return [C[0] + A[0] * u + B[0] * v, C[1] + A[1] * u + B[1] * v]; }
    var p1 = at(f, 0), p2 = at(0, f), far = at(L, 0), both = at(L, L), down = at(0, L);
    function sheet() { c.beginPath(); c.moveTo(p1[0], p1[1]); c.lineTo(far[0], far[1]); c.lineTo(both[0], both[1]); c.lineTo(down[0], down[1]); c.lineTo(p2[0], p2[1]); c.closePath(); }
    sheet(); c.fillStyle = lg(c, C[0], C[1], C[0] - 40, C[1] + 60, [[0, "#FAF5E8"], [1, "#E8DEC6"]]); c.fill();
    c.strokeStyle = "rgba(120,100,70,0.55)"; c.lineWidth = 1; sheet(); c.stroke();
    // Ruled lines parallel to the top edge, and handwriting when there is unread correspondence.
    c.save(); sheet(); c.clip();
    c.strokeStyle = "rgba(90,120,170,0.28)"; c.lineWidth = 1;
    for (var i = 1; i < 14; i++) { var a = at(0, i * 2.6 * k), b = at(L, i * 2.6 * k); c.beginPath(); c.moveTo(a[0], a[1]); c.lineTo(b[0], b[1]); c.stroke(); }
    if (s.unread > 0) {
        c.strokeStyle = "#26304A"; c.lineWidth = Math.max(0.8, 0.2 * k);   // real ink on real paper: blue-black in both modes c.lineCap = "round"; c.lineJoin = "round";
        var lines = Math.min(6, 1 + s.unread);
        for (var j = 1; j <= lines; j++) {
            var base = j * 2.6 * k + 2.6 * k - 0.6 * k, start = 2.5 * k + (j % 2) * 1.5 * k;
            c.beginPath();
            for (var t = 0; t < 30; t++) {   // a running hand: small loops riding the rule
                var p = at(start + t * 0.55 * k + Math.cos(t * 2.4 + j) * 0.25 * k, base - (0.35 + 0.35 * Math.sin(t * 2.4 + j)) * k);
                if (t === 0) c.moveTo(p[0], p[1]); else c.lineTo(p[0], p[1]);
            }
            c.stroke();
        }
    }
    c.restore();
    // The folded corner: the sheet's back, a shade darker, casting a small shadow.
    var tip = at(f, f);
    c.fillStyle = "rgba(0,0,0,0.18)"; c.beginPath(); c.moveTo(p1[0], p1[1]); c.lineTo(tip[0] + 1.5, tip[1] + 2); c.lineTo(p2[0], p2[1]); c.closePath(); c.fill();
    c.fillStyle = lg(c, (p1[0] + p2[0]) / 2, (p1[1] + p2[1]) / 2, tip[0], tip[1], [[0, "#EFE6D2"], [1, "#CDBF9F"]]);
    c.beginPath(); c.moveTo(p1[0], p1[1]); c.lineTo(tip[0], tip[1]); c.lineTo(p2[0], p2[1]); c.closePath(); c.fill();
    c.strokeStyle = "rgba(110,90,60,0.65)"; c.stroke();
    c.strokeStyle = "rgba(255,255,255,0.8)"; c.beginPath(); c.moveTo(p1[0], p1[1]); c.lineTo(p2[0], p2[1]); c.stroke();   // the crease
    if (!g.clipped) return;
    // Paperclip across the top edge, its long axis along −B (it reaches up off the sheet).
    paperclip(c, g.clip[0], g.clip[1], Math.atan2(-B[1], -B[0]), k);
}
function paperclip(c, x, y, angle, k) {
    c.save(); c.translate(x, y); c.rotate(angle);
    var wl = 8 * k, ww = 2.4 * k;
    function loops() {   // outer loop, then the inner one; x along the clip, y across it
        c.beginPath();
        c.moveTo(-wl * 0.25, ww * 0.22); c.lineTo(wl * 0.4, ww * 0.22);
        c.arc(wl * 0.4, -ww * 0.06, ww * 0.28, Math.PI / 2, -Math.PI / 2, true);
        c.lineTo(-wl * 0.4, -ww * 0.34);
        c.arc(-wl * 0.4, 0.03 * ww, ww * 0.37, -Math.PI / 2, Math.PI / 2, true);
        c.lineTo(wl * 0.5, ww * 0.4);
        c.arc(wl * 0.5, 0, ww * 0.4, Math.PI / 2, -Math.PI / 2, true);
        c.lineTo(-wl * 0.05, -ww * 0.4);
    }
    c.lineCap = "round"; c.lineJoin = "round";
    c.save(); c.translate(0.8, 1.2); c.strokeStyle = "rgba(0,0,0,0.3)"; c.lineWidth = Math.max(1.3, 0.5 * k); loops(); c.stroke(); c.restore();
    c.strokeStyle = "#8F969D"; c.lineWidth = Math.max(1.2, 0.42 * k); loops(); c.stroke();
    c.strokeStyle = "rgba(255,255,255,0.75)"; c.lineWidth = Math.max(0.5, 0.14 * k); loops(); c.stroke();
    c.restore();
}

// ── Tray: a printed symbol (an in-tray), ink with a faint impression, in a 24-unit box ──
function trayMark(c, size, ink) {
    var S = size / 24;
    c.save(); c.scale(S, S); c.lineJoin = "round"; c.lineCap = "round";
    function path() {
        c.beginPath(); c.moveTo(4, 14); c.lineTo(8.5, 14); c.lineTo(10, 16.5); c.lineTo(14, 16.5); c.lineTo(15.5, 14); c.lineTo(20, 14);
        c.moveTo(4, 14); c.lineTo(6.5, 6); c.lineTo(17.5, 6); c.lineTo(20, 14); c.lineTo(20, 19); c.lineTo(4, 19); c.closePath();
    }
    c.save(); c.translate(0.3, 0.4); path(); c.strokeStyle = "rgba(255,255,255,0.35)"; c.lineWidth = 1.8; c.stroke(); c.restore();
    path(); c.strokeStyle = ink || "#211C15"; c.lineWidth = 1.6; c.stroke();
    c.restore();
}

// Bake: drop shadow (blurred, dithered on/off at 40 %), then the object quantised to 7 levels.
// o: {kind ("paper" for the correspondence corner), k, E, W, H (device px), D, gc, state, ink, clip}
function bake(ctx, o) {
    var W = o.W, H = o.H, D = o.D || 1, gc = o.gc || 1, paperKind = o.kind === "paper";
    function place(dx, dy) { ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.clearRect(0, 0, W, H); ctx.save(); ctx.scale(D, D); ctx.translate(dx, dy + (paperKind ? 0 : H / D / 2)); }
    function shape() { if (paperKind) paper(ctx, W / D, H / D, o.k, o.state || {}, o.ink, o.clip); else draw(ctx, o.kind, o.k, o.E, o.state || {}, o.ink); }
    place(2, 2.5); shape(); ctx.restore();
    var shadow = M.blurAlpha(ctx.getImageData(0, 0, W, H).data, W, H, 2 * D);
    place(0, 0); shape(); ctx.restore();
    var px = ctx.getImageData(0, 0, W, H).data;
    M.quantise(px, W, H, 7, gc);
    var out = ctx.createImageData(W, H), q = out.data;
    for (var y = 0; y < H; y++) for (var x = 0; x < W; x++) {
        var i = (y * W + x) * 4;
        if (px[i + 3]) M.put(q, i, px[i], px[i + 1], px[i + 2], 255);
        else if (shadow[y * W + x] / 255 * 0.4 > M.thrPx(x, y, gc)) M.put(q, i, 0, 0, 0, 102);
    }
    ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.clearRect(0, 0, W, H);
    ctx.putImageData(out, 0, 0, 0, 0, W, H);
}

