import QtQuick
import QtQuick.Window
import "../theme"
import "../config"
import "../skin"
import "VellumPaint.js" as VellumPaint
import "PaintCache.js" as PaintCache
// A floating vellum strip (rail, dock, sheets): frayed edges with a baked drop shadow, fibre
// texture, and the accent wash fading along the strip. DESIGN-SYSTEM.md §3.13. The item is the
// strip; edges and shadow reach `margin` beyond it. offX/offY: the strip's screen position in
// logical px, so the texture is continuous between surfaces.
//
// Built from native items: the interior is a Rectangle of paper × (1 + amp) under the skin's
// vellum shade tile (exactly the painter's paper × texture); the edge band (fray, shadow) is a
// nine-slice painted once per palette and shared (Baked); only the wash (rail, dock) is painted
// per strip, once, and cached.
Item {
    id: root
    property bool horizontal: false
    property bool washed: true
    property bool solid: Settings.reading.edge === "solid"   // prompts and the lock use a solid edge
    property real offX: 0
    property real offY: 0
    readonly property int margin: 6
    readonly property int washInset: 9
    readonly property int band: 7                 // logical px of fray inside the strip
    readonly property int border: margin + band   // the nine-slice border
    readonly property int tile: 96                // edge length painted once and repeated
    readonly property real amp: Theme.textureAmp(true)

    // ── interior ──
    Item {
        x: root.band; y: root.band
        width: Math.max(0, root.width - 2 * root.band); height: Math.max(0, root.height - 2 * root.band)
        clip: true
        Rectangle {
            anchors.fill: parent
            readonly property color p: Theme.paper
            color: Qt.rgba(Math.min(1, p.r * (1 + root.amp)), Math.min(1, p.g * (1 + root.amp)), Math.min(1, p.b * (1 + root.amp)), 1)
        }
        Image {
            readonly property int period: 1024
            x: -(((root.offX + root.band) % period) + period) % period
            y: -(((root.offY + root.band) % period) + period) % period
            width: parent.width - x; height: parent.height - y
            source: SkinStore.manifest.vellumShade ? SkinStore.url(SkinStore.manifest.vellumShade) : ""
            fillMode: Image.Tile
            smooth: false
            opacity: 2 * root.amp / (1 + root.amp)
            visible: root.amp > 0
        }
    }

    // ── edges and shadow: one nine-slice per palette, shared ──
    readonly property string edgeKey: JSON.stringify(["vellum-edge", root.dpr, root.grain, Theme.mode, String(Theme.paper), String(Theme.fray),
                                                      String(Theme.edge), root.amp, root.solid, MaterialFields.installed])
    readonly property string edgeUrl: Baked.urls[edgeKey] || ""
    onEdgeKeyChanged: if (!edgeUrl && Baked.claim(edgeKey)) bakeKey = edgeKey
    Component.onCompleted: if (!edgeUrl && Baked.claim(edgeKey)) bakeKey = edgeKey
    Connections { target: Baked; function onClaimedChanged() { if (!root.edgeUrl && !root.bakeKey && Baked.claim(root.edgeKey)) root.bakeKey = root.edgeKey; } }
    Component.onDestruction: if (bakeKey) Baked.release(bakeKey)   // gone before it painted: let another claim it
    BorderImage {
        x: -root.margin; y: -root.margin
        width: (root.width + 2 * root.margin) * root.dpr; height: (root.height + 2 * root.margin) * root.dpr
        scale: 1 / root.dpr; transformOrigin: Item.TopLeft
        source: root.edgeUrl
        border { left: root.border * root.dpr; right: root.border * root.dpr; top: root.border * root.dpr; bottom: root.border * root.dpr }
        horizontalTileMode: BorderImage.Repeat; verticalTileMode: BorderImage.Repeat
        smooth: false
    }
    // Paints the shared edge image when this strip claimed it; exists only while it does.
    property string bakeKey: ""
    function release() { bakeKey = ""; }   // later than the canvas's own signal: unloading it inside one crashes
    readonly property real dpr: Screen.devicePixelRatio > 0 ? Screen.devicePixelRatio : 1
    readonly property int grain: Math.max(1, Math.round(Settings.option("pixel.logical") * dpr))
    Loader {
        active: root.bakeKey !== ""
        sourceComponent: RasterCanvas {
            id: baker
            property string done: ""            // painted, waiting for the canvas image
            opacity: 0                           // painted (polished) but never shown
            width: 2 * root.border + root.tile; height: width
            Component.onCompleted: Qt.callLater(baker.repaint)
            // toDataURL renders the canvas, which emits drawn again: clear the job first.
            onDrawn: if (done) { const key = done; done = ""; Baked.put(key, baker.canvasItem.toDataURL("image/png")); Qt.callLater(root.release); }
            onPainting: function(ctx, W, H) {
                if (!root.bakeKey || W !== Math.round(width * baker.dpr)) return;
                const D = baker.dpr, m = Math.round(root.margin * D), img = ctx.createImageData(W, H);
                VellumPaint.paintVellum(img.data, W, H, {x0: m, y0: m, w: W - 2 * m, h: H - 2 * m, D: D, gc: baker.grain, mode: Theme.mode,
                    base: String(Theme.paper), fray: String(Theme.fray), edge: String(Theme.edge), amp: root.amp, solidEdge: root.solid});
                // The middle is drawn natively (see above): keep only the border.
                const b = Math.round(root.border * D);
                for (let y = b; y < H - b; y++) for (let x = b; x < W - b; x++) img.data[(y * W + x) * 4 + 3] = 0;
                ctx.clearRect(0, 0, W, H); ctx.putImageData(img, 0, 0, 0, 0, W, H);
                done = root.bakeKey;
            }
        }
    }

    // ── the accent wash (rail, dock): painted per strip, once, cached ──
    RasterCanvas {
        id: wash
        visible: root.washed && !!Theme.wash
        x: root.washInset; y: root.washInset
        width: visible ? Math.max(0, root.width - 2 * root.washInset) : 0; height: visible ? Math.max(0, root.height - 2 * root.washInset) : 0
        onPainting: function(ctx, W, H) {
            const D = wash.dpr, w = Theme.wash;
            if (!w) { ctx.clearRect(0, 0, W, H); return; }
            const key = JSON.stringify(["wash", W, H, D, wash.grain, Theme.mode, w.tone, root.amp, root.horizontal, root.offX, root.offY, MaterialFields.installed]);
            const cached = PaintCache.get(key);
            ctx.clearRect(0, 0, W, H);
            if (cached) { ctx.putImageData(cached, 0, 0, 0, 0, W, H); return; }
            const img = ctx.createImageData(W, H);
            VellumPaint.paintWash(img.data, W, H, {x0: 0, y0: 0, w: W, h: H, tone: w.tone, horizontal: root.horizontal, radius: 9 * D, D: D,
                gc: wash.grain, amp: root.amp, mode: Theme.mode, offX: root.offX + root.washInset, offY: root.offY + root.washInset});
            ctx.putImageData(img, 0, 0, 0, 0, W, H);
            PaintCache.put(key, img);
        }
    }
    Connections {
        target: Theme
        function onModeChanged() { wash.repaint(); }
        function onWashChanged() { wash.repaint(); }
    }
}
