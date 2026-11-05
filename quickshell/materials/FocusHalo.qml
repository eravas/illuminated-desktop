import QtQuick
import QtQuick.Window
import "../theme"
import "../config"
import "Halo.js" as Halo
// Focus light around a rounded shape: solid core, dithered fringe. Options (§3.9):
// halo (2 px core + fringe), thick (core +1 px), solid (4 px core, no fringe).
// Anchor it to fill the focused item; it draws outside by `reach`.
// A nine-slice image painted once per style, corner radius, palette and grain, and shared
// (Baked): showing a halo costs no painting.
Item {
    id: root
    property real radius: 0
    readonly property string style: Settings.reading.focus
    readonly property real reach: style === "solid" ? 4 : 9
    readonly property int corner: Math.round(radius)
    readonly property int border: Math.ceil(reach) + corner + 1
    readonly property int tile: 32
    readonly property real dpr: Screen.devicePixelRatio > 0 ? Screen.devicePixelRatio : 1
    readonly property int grain: Math.max(1, Math.round(Settings.option("pixel.logical") * dpr))
    readonly property string key: JSON.stringify(["halo", style, corner, dpr, grain, String(Theme.focusCore), String(Theme.focusFringe)])
    readonly property string url: Baked.urls[key] || ""
    property string bakeKey: ""
    function release() { bakeKey = ""; }
    onKeyChanged: if (!url && Baked.claim(key)) bakeKey = key
    Component.onCompleted: if (!url && Baked.claim(key)) bakeKey = key
    Connections { target: Baked; function onClaimedChanged() { if (!root.url && !root.bakeKey && Baked.claim(root.key)) root.bakeKey = root.key; } }
    Component.onDestruction: if (bakeKey) Baked.release(bakeKey)   // gone before it painted: let another claim it
    BorderImage {
        x: -root.reach; y: -root.reach
        width: (root.width + 2 * root.reach) * root.dpr; height: (root.height + 2 * root.reach) * root.dpr
        scale: 1 / root.dpr; transformOrigin: Item.TopLeft
        source: root.url
        border { left: root.border * root.dpr; right: root.border * root.dpr; top: root.border * root.dpr; bottom: root.border * root.dpr }
        horizontalTileMode: BorderImage.Repeat; verticalTileMode: BorderImage.Repeat
        smooth: false
    }
    Loader {
        active: root.bakeKey !== ""
        sourceComponent: RasterCanvas {
            id: raster
            property string done: ""
            opacity: 0
            // The shape is a (tile + 2 × corner)-wide rounded square, `reach` inside the canvas.
            width: 2 * root.border + root.tile; height: width
            Component.onCompleted: Qt.callLater(raster.repaint)
            onDrawn: if (done) { const k = done; done = ""; Baked.put(k, raster.canvasItem.toDataURL("image/png")); Qt.callLater(root.release); }
            onPainting: function(ctx, W, H) {
                if (!root.bakeKey || W !== Math.round(width * raster.dpr)) return;
                const D = raster.dpr, m = Math.round(root.reach * D), img = ctx.createImageData(W, H);
                Halo.paintHalo(img.data, W, H, {x0: m, y0: m, w: W - 2 * m, h: H - 2 * m, radius: root.corner * D,
                    core: String(Theme.focusCore), fringe: String(Theme.focusFringe), D: D, gc: raster.grain,
                    coreWidth: root.style === "solid" ? 4 : root.style === "thick" ? 3 : 2, reach: root.style === "solid" ? 0 : 7});
                ctx.clearRect(0, 0, W, H); ctx.putImageData(img, 0, 0, 0, 0, W, H);
                done = root.bakeKey;
            }
        }
    }
}
