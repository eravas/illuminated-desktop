.pragma library
// The letter on an illuminated initial (the fallback icon for a hand without a skin element):
// live text with a light halo, drawn with the QML Context2D subset. The gold ground is a skin
// image (docs/SKINS.md, "initial").

// The letter or glyph, drawn with the QML Context2D subset (also valid on HTML canvas).
// mark: a single letter, or "launcher" | "clipboard" | "tray".
var INITIAL_INK = "#1E140A", INITIAL_HALO = "rgba(255,244,214,0.55)";
function drawInitialMark(ctx, mark, W, D, family) {
    var S = W / 24;
    ctx.save();
    if (mark === "launcher" || mark === "clipboard" || mark === "tray") {
        ctx.scale(S, S);
        ctx.lineJoin = "round"; ctx.lineCap = "round";
        ctx.beginPath();
        if (mark === "launcher") {
            var cells = [[4.6, 6.2], [10.4, 6.2], [16.2, 6.2], [4.6, 12.6], [10.4, 12.6], [16.2, 12.6]];
            for (var k = 0; k < cells.length; k++) ctx.rect(cells[k][0], cells[k][1], 3.2, 4);
            ctx.strokeStyle = "rgba(255,244,214,0.6)"; ctx.lineWidth = 1.2; ctx.stroke();
            ctx.fillStyle = INITIAL_INK; ctx.fill();
        } else {
            if (mark === "clipboard") {
                ctx.rect(6.5, 5.5, 11, 14);
                ctx.moveTo(9.5, 5.5); ctx.lineTo(9.5, 3.8); ctx.lineTo(14.5, 3.8); ctx.lineTo(14.5, 5.5);
                ctx.moveTo(9, 10); ctx.lineTo(15, 10); ctx.moveTo(9, 13); ctx.lineTo(15, 13); ctx.moveTo(9, 16); ctx.lineTo(13, 16);
            } else {
                ctx.moveTo(4, 14); ctx.lineTo(8, 14); ctx.lineTo(9.5, 16.5); ctx.lineTo(14.5, 16.5); ctx.lineTo(16, 14); ctx.lineTo(20, 14);
                ctx.moveTo(4, 14); ctx.lineTo(6, 6); ctx.lineTo(18, 6); ctx.lineTo(20, 14); ctx.lineTo(20, 19); ctx.lineTo(4, 19); ctx.closePath();
            }
            ctx.strokeStyle = "rgba(255,244,214,0.6)"; ctx.lineWidth = 3.4; ctx.stroke();
            ctx.strokeStyle = INITIAL_INK; ctx.lineWidth = 1.6; ctx.stroke();
        }
    } else {
        ctx.textAlign = "center"; ctx.textBaseline = "middle";
        ctx.font = Math.round(25 * D) + "px \"" + (family || "Pirata One") + "\"";
        ctx.lineWidth = 2.2 * D; ctx.strokeStyle = INITIAL_HALO; ctx.strokeText(mark, W / 2, W / 2 + 1.5 * D);
        ctx.fillStyle = INITIAL_INK; ctx.fillText(mark, W / 2, W / 2 + 1.5 * D);
    }
    ctx.restore();
}

