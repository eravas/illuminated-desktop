.pragma library
.import "../Materials.js" as M
.import "../../../quickshell/materials/DeviceGeometry.js" as Geo
// Painters for the default skin's removable media (scripts/skin/build-default.cjs). Not loaded
// by the shell, which draws the images these write. Removable-media objects (SURFACES.md §2a): life-size painted devices, quantised through
// the ordered dither at the logical-pixel grain. Ported from the Rail and Dock swatch.
//
// Drawing uses only the QML Context2D subset: roundedRect, fillRule, createConicalGradient,
// no Path2D, no filter, no drawImage of other canvases. Shadows and the wax seal are
// composited here in JavaScript from getImageData passes, so one Canvas does everything.
//
// Device-local units: each device is drawn leading end at x = 0, extending to −L, centred on
// y = 0 (sideways devices: top end along the rail). `real` mm map to `drawn` units.

function rr(ctx, x, y, w, h, r) { ctx.beginPath(); ctx.roundedRect(x, y, w, h, r, r); }
function lg(ctx, x0, y0, x1, y1, stops) {
    var g = ctx.createLinearGradient(x0, y0, x1, y1);
    for (var i = 0; i < stops.length; i++) g.addColorStop(stops[i][0], stops[i][1]);
    return g;
}
var ODD = typeof Qt !== "undefined" ? Qt.OddEvenFill : 0, WINDING = typeof Qt !== "undefined" ? Qt.WindingFill : 1;
function fillOdd(ctx) { ctx.fillRule = ODD; ctx.fill(); ctx.fillRule = WINDING; }

var DEVICES = {
    usb: {
        shape: function (ctx) { rr(ctx, -67, -11, 53, 22, 5); ctx.rect(-15, -7.3, 15, 14.6); },
        draw: function (ctx) {
            rr(ctx, -67, -11, 53, 22, 5); ctx.fillStyle = lg(ctx, 0, -11, 0, 11, [[0, "#3E63A8"], [0.35, "#25467F"], [1, "#132748"]]); ctx.fill();
            ctx.fillStyle = "rgba(255,255,255,0.28)"; ctx.fillRect(-63, -9, 46, 2); ctx.fillStyle = "rgba(0,0,0,0.25)"; ctx.fillRect(-63, 8, 46, 2);
            ctx.fillStyle = lg(ctx, 0, -7.3, 0, 7.3, [[0, "#F4F5F6"], [0.3, "#C9CDD1"], [0.7, "#8D9399"], [1, "#5E646A"]]); ctx.fillRect(-15, -7.3, 15, 14.6);
            ctx.fillStyle = "#2A2D31"; ctx.fillRect(-9.5, -5.2, 3.2, 3.4); ctx.fillRect(-9.5, 1.8, 3.2, 3.4);
            ctx.fillStyle = "rgba(255,255,255,0.6)"; ctx.fillRect(-15, -7.3, 15, 1); ctx.fillStyle = "rgba(0,0,0,0.3)"; ctx.fillRect(-15, -7.3, 1, 14.6); ctx.fillStyle = "rgba(0,0,0,0.35)"; ctx.fillRect(-1, -7.3, 1, 14.6);
        }},
    sd: {
        shape: function (ctx) { ctx.beginPath(); ctx.moveTo(-43, -16); ctx.lineTo(0, -16); ctx.lineTo(0, 10); ctx.lineTo(-6, 16); ctx.lineTo(-43, 16); ctx.closePath(); },
        draw: function (ctx) {
            this.shape(ctx); ctx.fillStyle = lg(ctx, 0, -16, 0, 16, [[0, "#383B41"], [0.5, "#2A2D32"], [1, "#1A1C20"]]); ctx.fill();
            var pads = [-14.2, -10.9, -7.6, -4.3, -1, 2.3, 5.6, 8.9, 12];
            for (var i = 0; i < pads.length; i++) { var y = pads[i], len = i === 8 ? 4.4 : 5.6, x1 = i === 8 ? -5.4 : -1.6;
                ctx.fillStyle = lg(ctx, 0, y, 0, y + 2.4, [[0, "#F3D98A"], [0.5, "#D6A93E"], [1, "#A87A22"]]); ctx.fillRect(x1 - len, y, len, 2.4); }
            ctx.fillStyle = "rgba(255,255,255,0.08)"; ctx.fillRect(-40, -14, 30, 1); ctx.fillRect(-40, 12, 30, 1);
            ctx.fillStyle = "rgba(0,0,0,0.35)"; ctx.fillRect(-20, -16, 1, 32);
            ctx.fillStyle = "rgba(255,255,255,0.3)"; ctx.fillRect(-43, -16, 43, 1); ctx.fillStyle = "rgba(255,255,255,0.18)"; ctx.fillRect(-1, -16, 1, 26);
        }},
    disc: {
        shape: function (ctx) { ctx.beginPath(); ctx.arc(0, 0, this.R, 0, Math.PI * 2); },
        draw: function (ctx) {
            var R = this.R;
            ctx.beginPath(); ctx.arc(0, 0, R, 0, Math.PI * 2);
            var rg = ctx.createRadialGradient(-20, -30, 10, 0, 0, R); rg.addColorStop(0, "#F2F3F5"); rg.addColorStop(0.7, "#C9CDD3"); rg.addColorStop(1, "#AEB3BA"); ctx.fillStyle = rg; ctx.fill();
            var cg = ctx.createConicalGradient(0, 0, -0.6), cols = ["#FF9AA8", "#FFD58A", "#C8F59A", "#8FE6F0", "#A7A6FF", "#F4A2F0", "#FF9AA8"];
            for (var i = 0; i < cols.length; i++) cg.addColorStop(i / (cols.length - 1), cols[i]);
            ctx.globalAlpha = 0.24; ctx.beginPath(); ctx.arc(0, 0, R - 5, 0, Math.PI * 2); ctx.arc(0, 0, R * 0.45, 0, Math.PI * 2, true); ctx.fillStyle = cg; fillOdd(ctx); ctx.globalAlpha = 1;
            ctx.beginPath(); ctx.arc(0, 0, R, 0, Math.PI * 2); ctx.arc(0, 0, R - 4, 0, Math.PI * 2, true); ctx.fillStyle = "rgba(235,240,245,0.85)"; fillOdd(ctx);
            ctx.strokeStyle = "rgba(90,96,104,0.55)"; ctx.lineWidth = 1; ctx.beginPath(); ctx.arc(0, 0, R - 4.5, 0, Math.PI * 2); ctx.stroke();
            ctx.strokeStyle = "rgba(255,255,255,0.7)"; ctx.lineWidth = 2; ctx.beginPath(); ctx.arc(0, 0, R - 1, -0.55, -0.15); ctx.stroke();
        }},
    drive: {
        shape: function (ctx) { rr(ctx, -72, -25, 72, 50, 2); },
        draw: function (ctx) {
            rr(ctx, -72, -25, 72, 50, 2); ctx.fillStyle = lg(ctx, -72, -25, 0, 25, [[0, "#D5D9DD"], [0.5, "#BCC1C6"], [1, "#959BA1"]]); ctx.fill();
            ctx.strokeStyle = "rgba(255,255,255,0.55)"; ctx.lineWidth = 0.5; rr(ctx, -69.5, -22.5, 67, 45, 3); ctx.stroke(); ctx.strokeStyle = "rgba(80,86,94,0.45)"; rr(ctx, -69, -22, 66, 44, 3); ctx.stroke();
            ctx.save(); this.shape(ctx); ctx.clip(); ctx.fillStyle = "rgba(255,255,255,0.07)"; for (var x = -72; x < 0; x += 0.8) ctx.fillRect(x, -25, 0.25, 50); ctx.restore();
            var L0 = -63, L1 = -6; ctx.fillStyle = "#F7F7F4"; ctx.fillRect(L0, -21, L1 - L0, 46);
            ctx.fillStyle = lg(ctx, 0, -21, 0, 25, [[0, "#1F4E9A"], [1, "#2A63B8"]]); ctx.fillRect(-15, -21, 9, 46); ctx.fillRect(L0, -21, 7, 46);
            ctx.fillStyle = "rgba(255,255,255,0.85)"; ctx.fillRect(-11.5, -17, 1.4, 16); ctx.fillRect(-11.5, 3, 1.4, 10); ctx.fillRect(-59.5, -17, 1.6, 12); ctx.fillRect(-59.5, 0, 1.2, 18);
            ctx.fillStyle = "#1C1D20"; ctx.fillRect(-21, -18, 3.4, 9); ctx.fillRect(-21, -6, 1.6, 24);
            for (var i = 0; i < 34; i++) { var w = (i * 7 % 3) * 0.18 + 0.18; ctx.fillRect(-27, -19 + i * 1.2, w + 0.4, 0.6); }
            for (var r = 0; r < 9; r++) { ctx.fillStyle = "rgba(30,30,32," + (0.55 - r * 0.03).toFixed(2) + ")"; ctx.fillRect(-32 - r * 2.6, -19, 0.7, 18 + ((r * 5) % 14)); }
            ctx.fillStyle = "rgba(30,30,32,0.6)"; for (var a = 0; a < 3; a++) for (var b = 0; b < 5; b++) ctx.fillRect(-53 + a * 2.4, -17 + b * 8.6, 1.6, 5.6);
            ctx.strokeStyle = "rgba(0,0,0,0.15)"; ctx.lineWidth = 0.4; ctx.strokeRect(L0, -21, L1 - L0, 46);
            var screws = [[-2.6, -22.4], [-2.6, 22.4], [-69.4, -22.4], [-69.4, 22.4]];
            for (var s = 0; s < 4; s++) { var sx = screws[s][0], sy = screws[s][1];
                ctx.fillStyle = "#6C7178"; ctx.beginPath(); ctx.arc(sx, sy, 1.5, 0, 7); ctx.fill();
                ctx.strokeStyle = "#2E3237"; ctx.lineWidth = 0.4; ctx.beginPath(); ctx.moveTo(sx - 0.9, sy); ctx.lineTo(sx + 0.9, sy); ctx.moveTo(sx, sy - 0.9); ctx.lineTo(sx, sy + 0.9); ctx.stroke(); }
            ctx.fillStyle = "rgba(255,255,255,0.6)"; ctx.fillRect(-71, -25, 70, 0.6); ctx.fillStyle = "rgba(0,0,0,0.3)"; ctx.fillRect(-71, 24.4, 70, 0.6);
        }},
    ssd: {
        shape: function (ctx) { ctx.beginPath(); ctx.moveTo(-80, -11); ctx.lineTo(0, -11); ctx.lineTo(0, 3.5); ctx.lineTo(-3.6, 3.5); ctx.lineTo(-3.6, 5.2); ctx.lineTo(0, 5.2); ctx.lineTo(0, 11); ctx.lineTo(-77, 11); ctx.arc(-77, 8, 3, Math.PI / 2, Math.PI); ctx.lineTo(-80, -11); ctx.closePath(); },
        draw: function (ctx) {
            this.shape(ctx); ctx.fillStyle = lg(ctx, 0, -11, 0, 11, [[0, "#24272B"], [0.5, "#17191C"], [1, "#0F1012"]]); ctx.fill();
            for (var y = -10.2; y < 10.4; y += 0.85) { if (y > 3 && y < 5.6) continue; ctx.fillStyle = lg(ctx, -3.6, 0, 0, 0, [[0, "#B98A2C"], [0.5, "#F0CF77"], [1, "#C79A38"]]); ctx.fillRect(-3.4, y, 3.4, 0.55); }
            ctx.fillStyle = lg(ctx, -72, -10, -6, 10, [[0, "#1B1C1F"], [0.5, "#232428"], [1, "#18191B"]]); ctx.fillRect(-72, -10, 66, 20);
            ctx.save(); ctx.beginPath(); ctx.rect(-72, -10, 66, 20); ctx.clip(); ctx.fillStyle = "rgba(255,255,255,0.035)"; for (var k = -80; k < 0; k += 2.2) ctx.fillRect(k, -10, 0.9, 20); ctx.restore();
            ctx.fillStyle = "rgba(205,208,214,0.75)"; ctx.fillRect(-66, -6, 20, 1.4); ctx.fillStyle = "rgba(170,174,180,0.55)"; ctx.fillRect(-66, -2.6, 28, 0.8); ctx.fillRect(-66, -0.6, 18, 0.8); ctx.fillRect(-66, 4.6, 12, 0.8);
            ctx.fillStyle = "rgba(150,154,160,0.6)"; ctx.fillRect(-36, 6.2, 26, 0.5);
            ctx.strokeStyle = "rgba(255,255,255,0.08)"; ctx.lineWidth = 0.4; ctx.strokeRect(-72, -10, 66, 20);
            ctx.strokeStyle = "#C9A14A"; ctx.lineWidth = 0.5; ctx.beginPath(); ctx.arc(-77, 8, 1.6, 0, 7); ctx.stroke();
            ctx.fillStyle = "rgba(255,255,255,0.16)"; ctx.fillRect(-80, -11, 76, 0.6);
        }},
    android: {
        shape: function (ctx) { rr(ctx, -107, -25, 107, 50, 4.5); },
        draw: function (ctx) {
            rr(ctx, -107, -25, 107, 50, 4.5); ctx.fillStyle = lg(ctx, 0, -25, 0, 25, [[0, "#4E6B58"], [0.5, "#3A5444"], [1, "#2A3E32"]]); ctx.fill();
            ctx.fillStyle = "rgba(255,255,255,0.22)"; ctx.fillRect(-105, -25, 103, 0.7); ctx.fillStyle = "rgba(0,0,0,0.3)"; ctx.fillRect(-105, 24.3, 103, 0.7);
            rr(ctx, -106, -24, 105, 48, 3.8); ctx.fillStyle = "#0A0B0C"; ctx.fill();
            rr(ctx, -104.8, -22.8, 102.6, 45.6, 3.2); ctx.fillStyle = lg(ctx, -104, -22, -2, 22, [[0, "#24322B"], [0.55, "#2E3B45"], [1, "#1E2A2E"]]); ctx.fill();
            ctx.fillStyle = "rgba(255,255,255,0.75)"; ctx.fillRect(-5.4, -19.5, 1.1, 4); ctx.fillRect(-5.4, 14.5, 1.1, 2.5); ctx.fillRect(-5.4, 18, 1.1, 2.5);
            ctx.fillStyle = "rgba(255,255,255,0.55)"; ctx.fillRect(-62, -9, 9, 18); ctx.fillStyle = "rgba(255,255,255,0.35)"; ctx.fillRect(-49, -6, 1.6, 12);
            ctx.fillStyle = "#050506"; ctx.beginPath(); ctx.arc(-3.9, 0, 1.45, 0, 7); ctx.fill(); ctx.strokeStyle = "rgba(120,130,150,0.5)"; ctx.lineWidth = 0.35; ctx.beginPath(); ctx.arc(-3.9, 0, 1.05, 0, 7); ctx.stroke();
            rr(ctx, -34, 24.6, 10, 1.4, 0.6); ctx.fillStyle = "#F2C230"; ctx.fill();
            rr(ctx, -52, 24.6, 14, 1.2, 0.6); ctx.fillStyle = "#2F4638"; ctx.fill();
        }},
    iphone: {
        shape: function (ctx) { rr(ctx, -103, -25, 103, 50, 8); },
        draw: function (ctx) {
            rr(ctx, -103, -25, 103, 50, 8); ctx.fillStyle = lg(ctx, 0, -25, 0, 25, [[0, "#E6E8EB"], [0.5, "#B9BDC2"], [1, "#8E9399"]]); ctx.fill();
            rr(ctx, -102, -24, 101, 48, 7); ctx.fillStyle = "#0B0C0E"; ctx.fill();
            rr(ctx, -100.6, -22.6, 98.2, 45.2, 6); ctx.fillStyle = lg(ctx, -100, -22, -2, 22, [[0, "#2A3346"], [0.55, "#3B3550"], [1, "#1E2A33"]]); ctx.fill();
            ctx.fillStyle = "rgba(255,255,255,0.75)"; ctx.fillRect(-5.2, -19, 1.1, 4); ctx.fillRect(-5.2, 14, 1.1, 2.5); ctx.fillRect(-5.2, 17.5, 1.1, 2.5);
            ctx.fillStyle = "rgba(255,255,255,0.55)"; ctx.fillRect(-60, -9, 9, 18); ctx.fillStyle = "rgba(255,255,255,0.35)"; ctx.fillRect(-47, -6, 1.6, 12);
            rr(ctx, -6.4, -6, 3, 12, 1.5); ctx.fillStyle = "#050506"; ctx.fill(); ctx.fillStyle = "rgba(90,100,120,0.6)"; ctx.beginPath(); ctx.arc(-4.9, 3.6, 0.7, 0, 7); ctx.fill();
            ctx.fillStyle = "rgba(255,255,255,0.35)"; ctx.fillRect(-101, -25, 99, 0.6); ctx.fillStyle = "rgba(0,0,0,0.35)"; ctx.fillRect(-101, 24.4, 99, 0.6);
        }},
    pico: {
        shape: function (ctx) { rr(ctx, -51, -10.5, 51, 21, 1); ctx.rect(-2.6, -4, 3.2, 8); },
        draw: function (ctx) {
            rr(ctx, -51, -10.5, 51, 21, 1); ctx.fillStyle = lg(ctx, 0, -10.5, 0, 10.5, [[0, "#2E8C4A"], [0.5, "#1F7339"], [1, "#165A2C"]]); ctx.fill();
            for (var i = 0; i < 20; i++) { var x = -(1.9 + i * 2.54); for (var s = 0; s < 2; s++) { var y = s ? 10.5 : -10.5;
                ctx.fillStyle = "#E1B95A"; ctx.beginPath(); ctx.arc(x, y, 1, 0, 7); ctx.fill(); ctx.fillStyle = "#0E2C18"; ctx.beginPath(); ctx.arc(x, y, 0.55, 0, 7); ctx.fill(); } }
            ctx.fillStyle = lg(ctx, 0, -4, 0, 4, [[0, "#EEF0F2"], [0.5, "#B7BCC2"], [1, "#7F858C"]]); ctx.fillRect(-2.6, -4, 3.2, 8); ctx.fillStyle = "#2B2E33"; ctx.fillRect(-0.6, -2.6, 1, 5.2);
            ctx.fillStyle = "#141518"; ctx.fillRect(-28, -3.5, 7, 7); ctx.fillStyle = "rgba(255,255,255,0.12)"; ctx.fillRect(-28, -3.5, 7, 0.5);
            ctx.fillStyle = "#1A1B1E"; ctx.fillRect(-18, -7.6, 4.2, 3); ctx.fillStyle = "#C9CCD0"; ctx.fillRect(-33.5, -2, 2.2, 4);
            ctx.fillStyle = "#E9E7E2"; rr(ctx, -11, 3.6, 3.4, 3.4, 0.4); ctx.fill(); ctx.fillStyle = "#BDB9B0"; ctx.beginPath(); ctx.arc(-9.3, 5.3, 1, 0, 7); ctx.fill();
            ctx.fillStyle = "#9EE6A6"; ctx.fillRect(-6.2, -7.4, 1, 0.8); ctx.fillStyle = "#D7DADD"; for (var k = 0; k < 3; k++) ctx.fillRect(-50, -3.4 + k * 2.6, 1.6, 1.6);
            ctx.strokeStyle = "rgba(240,240,235,0.5)"; ctx.lineWidth = 0.25; ctx.strokeRect(-46, -8, 12, 16);
        }},
    esp32: {
        shape: function (ctx) { rr(ctx, -55, -14, 55, 28, 1); },
        draw: function (ctx) {
            rr(ctx, -55, -14, 55, 28, 1); ctx.fillStyle = lg(ctx, 0, -14, 0, 14, [[0, "#283144"], [0.5, "#1C2433"], [1, "#141A25"]]); ctx.fill();
            for (var s = 0; s < 2; s++) { var y = s ? 12.3 : -12.3; ctx.fillStyle = "#15161A"; ctx.fillRect(-53, y - 1.3, 44, 2.6);
                for (var i = 0; i < 17; i++) { ctx.fillStyle = "#E1B95A"; ctx.fillRect(-52.2 + i * 2.54, y - 0.45, 0.9, 0.9); } }
            ctx.fillStyle = "#22262E"; ctx.fillRect(-27, -9, 27, 18);
            ctx.fillStyle = lg(ctx, -25, -8, -9, 8, [[0, "#E8EAED"], [0.5, "#BEC3C9"], [1, "#8C9298"]]); ctx.fillRect(-25, -8, 16, 16); ctx.strokeStyle = "rgba(80,86,94,0.6)"; ctx.lineWidth = 0.3; ctx.strokeRect(-24, -7, 14, 14);
            ctx.strokeStyle = "#D9B25A"; ctx.lineWidth = 0.6; ctx.beginPath(); ctx.moveTo(-7, -7);
            for (var k = 0; k < 6; k++) { ctx.lineTo(-7 + (k % 2 ? -2.2 : 0), -7 + k * 2.6); ctx.lineTo(-7 + (k % 2 ? 0 : -2.2), -7 + k * 2.6 + 1.3); }
            ctx.lineTo(-2, 7); ctx.stroke();
            for (var b = 0; b < 2; b++) { var by = b ? 7 : -7; ctx.fillStyle = "#111214"; ctx.fillRect(-49, by - 2, 4, 4); ctx.fillStyle = "#6E737A"; ctx.beginPath(); ctx.arc(-47, by, 1.2, 0, 7); ctx.fill(); }
            ctx.fillStyle = lg(ctx, -55, 0, -50, 0, [[0, "#7F858C"], [1, "#D5D9DD"]]); ctx.fillRect(-55.5, -4, 4.5, 8); ctx.fillStyle = "#1A1B1E"; ctx.fillRect(-36, -3, 4, 6); ctx.fillStyle = "#FFB37A"; ctx.fillRect(-40, 9, 1.2, 0.9);
        }},
    ereader: {
        shape: function (ctx) { rr(ctx, -85, -30, 85, 60, 4); },
        draw: function (ctx) {
            rr(ctx, -85, -30, 85, 60, 4); ctx.fillStyle = lg(ctx, 0, -30, 0, 30, [[0, "#353B4C"], [0.5, "#262B39"], [1, "#1B1F2A"]]); ctx.fill();
            rr(ctx, -78, -27.5, 75, 55, 1); ctx.fillStyle = "#D8D6CE"; ctx.fill();
            for (var r = 0; r < 22; r++) { var x = -74 + r * 3.1; if (r === 7 || r === 15) continue; var len = r === 6 || r === 14 ? 28 : 46 + ((r * 7) % 5); ctx.fillStyle = "rgba(40,40,42,0.62)"; ctx.fillRect(x, -24, 1, len); }
            ctx.fillStyle = "rgba(40,40,42,0.45)"; ctx.fillRect(-6.5, -3, 1, 6);
            ctx.fillStyle = "rgba(255,255,255,0.18)"; ctx.fillRect(-84, -30, 82, 0.6);
        }},
    cf: {
        shape: function (ctx) { rr(ctx, -36, -21.5, 36, 43, 1); },
        draw: function (ctx) {
            rr(ctx, -36, -21.5, 36, 43, 1); ctx.fillStyle = lg(ctx, 0, -21.5, 0, 21.5, [[0, "#33363C"], [0.5, "#24272C"], [1, "#18191C"]]); ctx.fill();
            for (var r = 0; r < 2; r++) for (var i = 0; i < 25; i++) { ctx.fillStyle = "#0A0A0B"; ctx.beginPath(); ctx.arc(-1.1 - r * 1.3, -19.2 + i * 1.6, 0.42, 0, 7); ctx.fill(); }
            ctx.fillStyle = "#C9CDD2"; ctx.fillRect(-32, -17, 24, 34); ctx.fillStyle = "rgba(40,42,46,0.55)"; ctx.fillRect(-28, -12, 2.4, 18); ctx.fillRect(-23, -12, 1, 24); ctx.fillRect(-20, -12, 1, 14); ctx.fillRect(-14, -8, 1, 16);
            ctx.fillStyle = "rgba(0,0,0,0.35)"; ctx.fillRect(-36, -21.5, 26, 0.8); ctx.fillRect(-36, 20.7, 26, 0.8);
        }},
    ms: {
        shape: function (ctx) { ctx.beginPath(); ctx.moveTo(-31, -10); ctx.lineTo(0, -10); ctx.lineTo(0, 10); ctx.lineTo(-28, 10); ctx.lineTo(-31, 7); ctx.closePath(); },
        draw: function (ctx) {
            this.shape(ctx); ctx.fillStyle = lg(ctx, 0, -10, 0, 10, [[0, "#3A3D44"], [0.5, "#26292E"], [1, "#18191C"]]); ctx.fill();
            for (var i = 0; i < 10; i++) { var y = -8.6 + i * 1.75; ctx.fillStyle = "#111214"; ctx.fillRect(-4.2, y - 0.2, 4.2, 1.65); ctx.fillStyle = lg(ctx, 0, y, 0, y + 1.1, [[0, "#F3D98A"], [1, "#B98A2C"]]); ctx.fillRect(-3.6, y + 0.15, 3.2, 1.1); }
            ctx.fillStyle = "#3E5F9C"; ctx.fillRect(-25, -7, 16, 14); ctx.fillStyle = "rgba(255,255,255,0.7)"; ctx.fillRect(-22, -4, 1.2, 8); ctx.fillRect(-18, -4, 0.8, 5);
        }},
    zip: {
        shape: function (ctx) { rr(ctx, -50, -25, 50, 50, 2); },
        draw: function (ctx) {
            rr(ctx, -50, -25, 50, 50, 2); ctx.fillStyle = lg(ctx, 0, -25, 0, 25, [[0, "#4A5568"], [0.5, "#36404F"], [1, "#262E3A"]]); ctx.fill();
            ctx.fillStyle = lg(ctx, -6, 0, 0, 0, [[0, "#2A313C"], [1, "#1B2028"]]); ctx.fillRect(-6, -11, 6, 22); ctx.fillStyle = "rgba(255,255,255,0.12)"; ctx.fillRect(-6, -11, 6, 0.5);
            ctx.fillStyle = "#E7E2D6"; ctx.fillRect(-42, -15, 22, 30); ctx.fillStyle = "rgba(60,60,60,0.35)"; for (var k = 0; k < 4; k++) ctx.fillRect(-38, -10 + k * 6, 14, 0.8);
            ctx.fillStyle = "rgba(0,0,0,0.25)"; for (var j = 0; j < 6; j++) { ctx.fillRect(-48 + j * 1.2, -23, 0.5, 6); ctx.fillRect(-48 + j * 1.2, 17, 0.5, 6); }
            ctx.fillStyle = "rgba(255,255,255,0.2)"; ctx.fillRect(-49, -25, 48, 0.6);
        }},
    floppy: {
        shape: function (ctx) { ctx.beginPath(); ctx.moveTo(-71, -34); ctx.lineTo(-4, -34); ctx.lineTo(0, -30); ctx.lineTo(0, 34); ctx.lineTo(-71, 34); ctx.closePath(); },
        draw: function (ctx) {
            this.shape(ctx); ctx.fillStyle = lg(ctx, 0, -34, 0, 34, [[0, "#3C3F45"], [0.5, "#2A2C31"], [1, "#1B1C20"]]); ctx.fill();
            ctx.fillStyle = lg(ctx, 0, -18, 0, 18, [[0, "#E9EBEE"], [0.4, "#B8BDC3"], [1, "#7E848B"]]); ctx.fillRect(-25, -18, 25, 36);
            ctx.fillStyle = "#2B2D31"; ctx.fillRect(-19, -6, 9, 12); ctx.fillStyle = "rgba(255,255,255,0.5)"; ctx.fillRect(-25, -18, 25, 1);
            ctx.fillStyle = "#E8E2D2"; ctx.fillRect(-66, -27, 36, 54); ctx.fillStyle = "rgba(60,60,60,0.35)"; for (var k = 0; k < 4; k++) ctx.fillRect(-62, -18 + k * 11, 28, 1.2);
            ctx.fillStyle = "#141518"; ctx.fillRect(-69, 27, 4, 4); ctx.fillStyle = "rgba(255,255,255,0.25)"; ctx.fillRect(-71, -34, 67, 1);
        }}
};
// Dimensions live in DeviceGeometry.js (shared with the shell); this file adds the drawing.
for (var k in Geo.DEVICES) { DEVICES[k] = DEVICES[k] || {}; for (var f in Geo.DEVICES[k]) DEVICES[k][f] = Geo.DEVICES[k][f]; }
var KINDS = Geo.KINDS;

function envelope(c, dv) {
    var m = 2; c.save();
    if (dv.disc) {
        var R = dv.R + m; c.beginPath(); c.arc(0, 0, R, 0, 7); c.globalAlpha = 0.84; c.fillStyle = lg(c, -R, -R, R, R, [[0, "#E2CFA6"], [1, "#CDB688"]]); c.fill(); c.globalAlpha = 1;
        c.strokeStyle = "rgba(95,70,35,0.6)"; c.lineWidth = 0.8; c.stroke(); c.beginPath(); c.arc(0, 0, R * 0.82, -0.5, 0.5); c.strokeStyle = "rgba(95,70,35,0.35)"; c.stroke(); c.restore(); return;
    }
    var L = dv.L, W = dv.drawn, x0 = -L - m, y0 = -W / 2 - m, ww = L + 2 * m, hh = W + 2 * m;
    c.globalAlpha = 0.84; c.fillStyle = lg(c, x0, y0, x0 + ww, y0 + hh, [[0, "#E2CFA6"], [1, "#CDB688"]]); c.fillRect(x0, y0, ww, hh); c.globalAlpha = 1;
    c.strokeStyle = "rgba(95,70,35,0.65)"; c.lineWidth = 0.5; c.strokeRect(x0 + 0.25, y0 + 0.25, ww - 0.5, hh - 0.5);
    var ey = y0 + hh, depth = Math.min(ww, hh) * 0.42, ax = x0 + ww * 0.5, ay = ey - depth;
    c.beginPath(); c.moveTo(x0, ey); c.lineTo(ax, ay); c.lineTo(x0 + ww, ey); c.closePath(); c.fillStyle = lg(c, 0, ay, 0, ey, [[0, "#D8C397"], [1, "#E6D5B0"]]); c.fill();
    c.strokeStyle = "rgba(95,70,35,0.7)"; c.lineWidth = 0.45; c.beginPath(); c.moveTo(x0, ey); c.lineTo(ax, ay); c.lineTo(x0 + ww, ey); c.stroke();
    c.strokeStyle = "rgba(95,70,35,0.28)"; c.beginPath(); c.moveTo(x0, y0); c.lineTo(ax, ay + depth * 0.15); c.lineTo(x0 + ww, y0); c.stroke();
    c.restore();
}
// Dark oxblood wax pressed with a padlock, centred at (x, y) logical px; cracked = after unlock.
function seal(c, x, y, cracked) {
    c.beginPath();
    for (var a = 0; a <= Math.PI * 2 + 0.01; a += Math.PI / 14) { var r = 12 + (Math.sin(a * 5) + Math.sin(a * 3 + 1)) * 0.9; c.lineTo(x + r * Math.cos(a), y + r * Math.sin(a)); }
    c.closePath();
    var g = c.createRadialGradient(x - 3, y - 3, 1, x, y, 10); g.addColorStop(0, "#8A3A2E"); g.addColorStop(0.7, "#5E2219"); g.addColorStop(1, "#3F150F"); c.fillStyle = g; c.fill();
    c.strokeStyle = "rgba(40,10,6,0.6)"; c.lineWidth = 1.2; c.beginPath(); c.arc(x, y, 8.4, 0, 7); c.stroke();
    c.strokeStyle = "rgba(255,190,170,0.25)"; c.beginPath(); c.arc(x - 0.5, y - 0.5, 8.4, Math.PI * 1.05, Math.PI * 1.6); c.stroke();
    c.save(); c.translate(x, y); c.scale(1.35, 1.35); c.translate(-x, -y);
    c.strokeStyle = "rgba(30,8,5,0.75)"; c.lineWidth = 1.3; c.beginPath(); c.arc(x, y - 1.6, 2.1, Math.PI, 0); c.stroke();
    c.fillStyle = "rgba(30,8,5,0.75)"; rr(c, x - 3.2, y - 1.6, 6.4, 4.8, 0.8); c.fill(); c.fillStyle = "rgba(255,190,170,0.35)"; c.fillRect(x - 3, y - 1.4, 6, 0.6);
    c.fillStyle = "#5E2219"; c.beginPath(); c.arc(x, y + 0.6, 0.8, 0, 7); c.fill(); c.fillRect(x - 0.35, y + 0.6, 0.7, 1.6);
    c.restore();
    if (cracked) { c.strokeStyle = "rgba(20,5,3,0.9)"; c.lineWidth = 1; c.beginPath(); c.moveTo(x - 11, y - 4); c.lineTo(x - 2, y + 1); c.lineTo(x + 3, y - 3); c.lineTo(x + 11, y + 5); c.stroke(); }
}
