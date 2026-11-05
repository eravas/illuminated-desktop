import QtQuick
import "../theme"
import "../config"
import "VellumPaint.js" as VellumPaint
import "PaintCache.js" as PaintCache
import "Fields.js" as Fields
// A floating vellum strip (rail, dock, sheets): frayed edges cut through interleaved-gradient
// noise, fibre texture at native resolution, baked drop shadow, and the accent wash fading
// along the strip. The item is the strip; the canvas reaches `margin` beyond it for the fray
// shadow. DESIGN-SYSTEM.md §3.13. offX/offY: the strip's screen position in logical px, so
// the texture is continuous between surfaces.
Item {
    id: root
    property bool horizontal: false
    property bool washed: true
    property bool solid: Settings.reading.edge === "solid"   // prompts and the lock use a solid edge
    onSolidChanged: raster.repaint()
    property real offX: 0
    property real offY: 0
    readonly property int margin: 6
    readonly property int washInset: 9
    RasterCanvas {
        id: raster
        x: -root.margin; y: -root.margin
        width: root.width + 2 * root.margin; height: root.height + 2 * root.margin
        onPainting: function(ctx, W, H) {
            const D = raster.dpr, m = Math.round(root.margin * D);
            const amp = Theme.textureAmp(true), wash = Theme.wash;
            // Everything the painters read: a repeat of the same strip is a putImageData.
            const key = JSON.stringify(["vellum", W, H, D, raster.grain, Theme.mode, String(Theme.paper), String(Theme.fray), String(Theme.edge), amp,
                                        root.solid, root.offX, root.offY, root.washed && wash ? [wash.tone, root.horizontal] : null, Fields.fieldsVersion()]);
            const cached = PaintCache.get(key);
            if (cached) { ctx.clearRect(0, 0, W, H); ctx.putImageData(cached, 0, 0, 0, 0, W, H); return; }
            const img = ctx.createImageData(W, H);
            VellumPaint.paintVellum(img.data, W, H, {x0: m, y0: m, w: W - 2 * m, h: H - 2 * m, D: D, gc: raster.grain, mode: Theme.mode,
                base: String(Theme.paper), fray: String(Theme.fray), edge: String(Theme.edge), amp: amp,
                solidEdge: root.solid, offX: root.offX, offY: root.offY});
            if (root.washed && wash) {
                const i = Math.round(root.washInset * D);
                VellumPaint.paintWash(img.data, W, H, {x0: m + i, y0: m + i, w: W - 2 * m - 2 * i, h: H - 2 * m - 2 * i, tone: wash.tone,
                    horizontal: root.horizontal, radius: 9 * D, D: D, gc: raster.grain, amp: amp, mode: Theme.mode,
                    offX: root.offX + root.washInset, offY: root.offY + root.washInset});
            }
            ctx.clearRect(0, 0, W, H);
            ctx.putImageData(img, 0, 0, 0, 0, W, H);
            PaintCache.put(key, img);
        }
    }
    Connections {
        target: Theme
        function onModeChanged() { raster.repaint(); }
        function onWashChanged() { raster.repaint(); }
    }
    Connections { target: Settings; function onReadingChanged() { raster.repaint(); } }
}
