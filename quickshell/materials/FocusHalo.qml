import QtQuick
import "../theme"
import "../config"
import "Halo.js" as Halo
// Focus light around a rounded shape: solid core, dithered fringe. Options (§3.9):
// halo (2 px core + fringe), thick (core +1 px), solid (4 px core, no fringe).
// Anchor it to fill the focused item; it draws outside by `reach`.
Item {
    id: root
    property real radius: 0
    readonly property string style: Settings.reading.focus
    readonly property real reach: style === "solid" ? 4 : 9
    RasterCanvas {
        id: raster
        x: -root.reach; y: -root.reach
        width: root.width + 2 * root.reach; height: root.height + 2 * root.reach
        onPainting: function(ctx, W, H) {
            const D = raster.dpr, m = Math.round(root.reach * D), img = ctx.createImageData(W, H);
            Halo.paintHalo(img.data, W, H, {x0: m, y0: m, w: W - 2 * m, h: H - 2 * m, radius: root.radius * D,
                core: String(Theme.focusCore), fringe: String(Theme.focusFringe), D: D, gc: raster.grain,
                coreWidth: root.style === "solid" ? 4 : root.style === "thick" ? 3 : 2, reach: root.style === "solid" ? 0 : 7});
            ctx.clearRect(0, 0, W, H); ctx.putImageData(img, 0, 0, 0, 0, W, H);
        }
    }
    onStyleChanged: raster.repaint()
    onRadiusChanged: raster.repaint()
    Connections { target: Theme; function onModeChanged() { raster.repaint(); } }
}
