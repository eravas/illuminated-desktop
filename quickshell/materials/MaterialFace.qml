pragma ComponentBehavior: Bound
import QtQuick
import "../theme"
import "../config"
import "../artifacts/CardModel.js" as CardModel
import "CardPaint.js" as CardPaint
// One card face as material (DESIGN-SYSTEM.md §3.5a–§3.6): cardstock, level wash or foil
// with its level mark, copper and patina, bands, chin tint, tonal back interiors, the
// placeholder art panel, rounded corners and the dog-ear cut. Text stays live on top (SplitText).
//
// A face is painted once per look, never per level. A face with a level (Sound, Light…) is
// layered: the dry face; the wet face (wash or foil everywhere, kept only where it differs),
// clipped at the level; the dithered edge past the level mark, taken from the face painted at
// half and moved to the level; for foil, a stronger-sheen wet layer cross-faded in with the
// level. The art's level-driven saturation and luminance are a grey copy of the art at
// 1 − saturation and a black overlay at 1 − luminance. Dragging a level runs no painter.
Item {
    id: root
    property var surface: null
    property bool front: true
    property color art: "#808080"           // placeholder art; luminance/saturation apply
    property bool artPanel: true             // false: plain face (device card)
    property real artLuminance: 1
    property real artSaturation: 1
    property real cut: 0                     // dog-ear corner cut away, logical px
    property string numeral: ""             // low-charge numeral over the art ("" = none)
    property bool live: false                // kept for callers; a drag no longer repaints
    // Card art (docs/SKINS.md, "cardArt"): an image URL, cover-fitted into the panel around
    // artFocus and rasterised once per size. Empty: the flat placeholder.
    property string artSource: ""
    property var artFocus: [0.5, 0.5]
    readonly property string artUrl: artSource && root.front && root.artPanel ? artSource : ""
    // Only the aspect is needed: a 64 px decode.
    Image { id: probe; visible: false; asynchronous: true; source: root.artUrl; sourceSize.width: 64 }
    property var artPixels: null
    onArtUrlChanged: artPixels = null
    readonly property var geo: CardModel.layout(width, height)
    readonly property var area: CardModel.washRect(surface ? surface.wash : null, width, height)
    // What the audio runtime suite measures: full card height, width = level × card width.
    Item {
        objectName: "service-level-fill"
        visible: false
        x: root.area.x; y: root.area.y; width: root.area.width; height: root.area.height
    }

    readonly property var wash: surface && surface.wash ? surface.wash : null
    readonly property bool layered: !!wash
    readonly property real level: wash ? Math.max(0, Math.min(1, wash.level)) : 0
    readonly property bool vertical: !!wash && wash.axis === "y"
    readonly property bool foil: !!wash && !!wash.foil
    readonly property string mark: Settings.reading.levelMark
    readonly property real spread: 12 * geo.k                 // logical px the mark dithers out
    // Everything a paint reads except the level (and, when layered, the art adjustments).
    readonly property string look: JSON.stringify([surface ? Object.assign({}, surface, {wash: wash ? Object.assign({}, wash, {level: 0}) : null}) : null,
        front, String(art), artPanel, cut, numeral, artUrl, probe.status, Settings.reading, Theme.mode, Theme.cardFamily, Theme.colourVision,
        layered ? 0 : artLuminance, layered ? 0 : artSaturation, width, height])
    onLookChanged: refresh()
    function refresh() { dry.repaint(); wet.repaint(); wetStrong.repaint(); edge.repaint(); grey.repaint(); }

    // A face spec: the dry face, or a wet layer. which: "dry" | "grey" | "wet" | "strong" | "edge"
    function faceSpec(raster, ctx, W, H, which) {
        const D = raster.dpr;
        let pixels = null;
        if (root.artUrl && probe.status === Image.Ready && probe.implicitWidth > 0) {
            const key = root.artUrl + "@" + W + "x" + H;
            if (!root.artPixels || root.artPixels.key !== key) {
                const got = raster.withImages([root.artUrl], () => CardPaint.rasteriseArt(ctx, W, H, D, root.artUrl, probe.implicitHeight / probe.implicitWidth, root.artFocus));
                if (got.value) root.artPixels = {key: key, px: got.value};
            }
            if (root.artPixels && root.artPixels.key === key) pixels = root.artPixels.px;
        }
        let s = root.surface;
        if (root.layered) {
            const w = Object.assign({}, root.wash);
            if (which === "dry" || which === "grey") w.level = 0;
            else if (which === "wet") { w.fill = true; w.sheenLevel = root.foil ? 0 : 1; }
            else if (which === "strong") { w.fill = true; w.sheenLevel = 0.95; }
            else if (which === "edge") w.level = 0.5;
            s = Object.assign({}, s, {wash: w});
        }
        return CardPaint.spec(s, {D: D, gc: raster.grain, front: root.front, cut: Math.round(root.cut * D),
            art: root.artPanel ? {rgb: String(root.art), luminance: root.layered ? 1 : root.artLuminance,
                                  saturation: which === "grey" ? 0 : root.layered ? 1 : root.artSaturation, pixels: pixels} : null,
            artStrength: Settings.reading.art === "muted" ? 0.5 : 1,
            mark: root.mark, cvd: Theme.colourVision, onFill: Theme.semantic("onFill")});
    }
    function numeralSpec(D) {
        if (!root.front || !root.numeral) return null;
        const g = root.geo;
        return {text: root.numeral, family: Theme.cardFamily, ink: String(Theme.ink), card: String(Theme.cardstock),
                size: Math.round(Math.min(92 * g.k, g.art.width * 0.86 / (0.62 * Math.max(1, root.numeral.length) + 0.21)) * D),
                art: {x: Math.round(g.art.x * D), y: Math.round(g.art.y * D), w: Math.round(g.art.width * D), h: Math.round(g.art.height * D)}};
    }
    // The dry face's pixels, to keep only what a layer changes.
    property var dryPixels: null
    function paintLayer(raster, ctx, W, H, which) {
        if (!root.surface) { ctx.clearRect(0, 0, W, H); return; }
        if (which === "dry") {
            const kept = CardPaint.paint(ctx, W, H, faceSpec(raster, ctx, W, H, "dry"), numeralSpec(raster.dpr), {keep: root.layered});
            if (root.layered) root.dryPixels = {W: W, H: H, px: kept};
            return;
        }
        // A layer waits for the dry face it is cut against (it repaints when that arrives).
        if (!root.layered || !root.dryPixels || root.dryPixels.W !== W || root.dryPixels.H !== H) { ctx.clearRect(0, 0, W, H); return; }
        CardPaint.paint(ctx, W, H, faceSpec(raster, ctx, W, H, which), numeralSpec(raster.dpr), {against: root.dryPixels.px});
    }
    onDryPixelsChanged: { wet.repaint(); wetStrong.repaint(); edge.repaint(); grey.repaint(); }

    RasterCanvas { id: dry; anchors.fill: parent; onPainting: function(ctx, W, H) { root.paintLayer(dry, ctx, W, H, "dry"); } }
    // Saturation follows the level on Sound and Microphone: grey art over the colour art.
    RasterCanvas {
        id: grey; anchors.fill: parent
        visible: root.layered && root.front && root.artPanel && root.artSaturation < 0.999
        opacity: 1 - root.artSaturation
        onPainting: function(ctx, W, H) { root.paintLayer(grey, ctx, W, H, "grey"); }
    }
    Rectangle {   // luminance follows the level on Light and Battery
        visible: root.layered && root.front && root.artPanel && root.artLuminance < 0.999
        x: root.geo.art.x; y: root.geo.art.y; width: root.geo.art.width; height: root.geo.art.height
        radius: root.geo.artRadius || 0
        color: "black"; opacity: 1 - root.artLuminance
    }
    // The wet face up to the level mark.
    Item {
        visible: root.layered && root.level > 0
        clip: !(root.level >= 0.999)
        x: 0; y: root.vertical ? root.height * (1 - root.level) : 0
        width: root.vertical ? root.width : root.width * root.level
        height: root.vertical ? root.height * root.level : root.height
        Item {
            y: -parent.y; width: root.width; height: root.height
            RasterCanvas { id: wet; anchors.fill: parent; onPainting: function(ctx, W, H) { root.paintLayer(wet, ctx, W, H, "wet"); } }
            RasterCanvas {   // foil: the sheen strengthens with the level
                id: wetStrong; anchors.fill: parent
                visible: root.foil
                opacity: Math.min(1, root.level / 0.95)
                onPainting: function(ctx, W, H) { root.paintLayer(wetStrong, ctx, W, H, root.foil ? "strong" : "none"); }
            }
        }
    }
    // The dithered edge past the mark (and the line or burnish at it), moved to the level.
    Item {
        visible: root.layered && root.level > 0 && root.level < 0.999 && root.mark !== "solid" || (root.foil && root.level > 0 && root.level < 0.999)
        clip: true
        readonly property real at: root.vertical ? root.height * (1 - root.level) : root.width * root.level
        readonly property real band: root.spread + 17 * root.geo.k      // the dither, and the foil's burnish behind the mark
        x: root.vertical ? 0 : at - band; y: root.vertical ? at - root.spread : 0
        width: root.vertical ? root.width : band + root.spread
        height: root.vertical ? band + root.spread : root.height
        Item {
            // In the half-level face the mark is at the middle.
            x: root.vertical ? 0 : -(root.width * 0.5 - parent.band)
            y: root.vertical ? -(root.height * 0.5 - root.spread) : 0
            width: root.width; height: root.height
            RasterCanvas { id: edge; anchors.fill: parent; onPainting: function(ctx, W, H) { root.paintLayer(edge, ctx, W, H, "edge"); } }
        }
    }
}
