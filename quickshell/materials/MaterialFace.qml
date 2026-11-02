import QtQuick
import "../theme"
import "../config"
import "../artifacts/CardModel.js" as CardModel
import "CardPaint.js" as CardPaint
// One card face as material (DESIGN-SYSTEM.md §3.5a–§3.6): cardstock, level wash or foil
// with its level mark, copper and patina, bands, chin tint, tonal back interiors, the
// placeholder art panel, rounded corners and the dog-ear cut. Painted into one Canvas and
// cached as a texture; text stays live on top (SplitText). Replaces v6's flat CardSurface.
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
    property bool live: false                // being dragged: throttle repaints
    // Card art (docs/SKINS.md, "cardArt"): an image URL, cover-fitted into the panel around
    // artFocus, rasterised once per size and kept as pixels; the level's luminance/saturation and
    // the dither grain are applied on every repaint. Empty: the flat placeholder.
    property string artSource: ""
    property var artFocus: [0.5, 0.5]
    readonly property string artUrl: artSource && root.front && root.artPanel ? artSource : ""
    // Only the aspect is needed: a 64 px decode.
    Image { id: probe; visible: false; asynchronous: true; source: root.artUrl; sourceSize.width: 64; onStatusChanged: root.refresh() }
    property var artPixels: null
    onArtUrlChanged: { artPixels = null; refresh(); }
    readonly property var geo: CardModel.layout(width, height)
    readonly property var area: CardModel.washRect(surface ? surface.wash : null, width, height)
    // What the audio runtime suite measures: full card height, width = level × card width.
    Item {
        objectName: "service-level-fill"
        visible: false
        x: root.area.x; y: root.area.y; width: root.area.width; height: root.area.height
    }
    function refresh() { raster.repaint(); }
    onSurfaceChanged: refresh()
    onFrontChanged: refresh()
    onArtChanged: refresh()
    onArtPanelChanged: refresh()
    onArtLuminanceChanged: refresh()
    onArtSaturationChanged: refresh()
    onCutChanged: refresh()
    onNumeralChanged: refresh()
    RasterCanvas {
        id: raster
        anchors.fill: parent
        coalesce: 33          // level changes (drag, keys) repaint at most ~30 times a second
        onPainting: function(ctx, W, H) {
            if (!root.surface) { ctx.clearRect(0, 0, W, H); return; }
            const D = raster.dpr;
            let pixels = null;
            if (root.artUrl && probe.status === Image.Ready && probe.implicitWidth > 0) {
                const r = CardPaint.artRect(W, H, D), key = root.artUrl + "@" + W + "x" + H;
                if (!root.artPixels || root.artPixels.key !== key) {
                    const got = raster.withImages([root.artUrl], () => CardPaint.rasteriseArt(ctx, W, H, D, root.artUrl, probe.implicitHeight / probe.implicitWidth, root.artFocus));
                    if (got.value) root.artPixels = {key: key, px: got.value};
                }
                if (root.artPixels && root.artPixels.key === key) pixels = root.artPixels.px;
            }
            const spec = CardPaint.spec(root.surface, {D: D, gc: raster.grain, front: root.front, cut: Math.round(root.cut * D),
                art: root.artPanel ? {rgb: String(root.art), luminance: root.artLuminance, saturation: root.artSaturation, pixels: pixels} : null,
                artStrength: Settings.reading.art === "muted" ? 0.5 : 1,
                mark: Settings.reading.levelMark, cvd: Theme.colourVision, onFill: Theme.semantic("onFill")});
            let num = null;
            if (root.front && root.numeral) {
                const g = root.geo;
                num = {text: root.numeral, family: Theme.cardFamily, ink: String(Theme.ink), card: String(Theme.cardstock),
                       size: Math.round(Math.min(92 * g.k, g.art.width * 0.86 / (0.62 * Math.max(1, root.numeral.length) + 0.21)) * D),
                       art: {x: Math.round(g.art.x * D), y: Math.round(g.art.y * D), w: Math.round(g.art.width * D), h: Math.round(g.art.height * D)}};
            }
            CardPaint.paint(ctx, W, H, spec, num);
        }
    }
    Connections { target: Settings; function onReadingChanged() { root.refresh(); } function onColourVisionChanged() { root.refresh(); } }
    Connections { target: Theme; function onModeChanged() { root.refresh(); } function onCardFamilyChanged() { root.refresh(); } }
}
