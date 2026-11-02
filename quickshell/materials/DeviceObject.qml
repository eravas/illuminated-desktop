import QtQuick
import "../skin"
import "../config"
import "DeviceGeometry.js" as Geo
import "DeviceArt.js" as Art
// A removable-media object painted life size and quantised through the dither
// (SURFACES.md §2a). Coordinates are the rail window's: x from the screen edge, `cy` the
// centre of the device bay above the tray. Two bakes: `rest` for the settled pose (on the
// logical-pixel grid) and, while moving, the unmounted bake turned by a QML transform.
Item {
    id: root
    property string kind: "ssd"
    property string pose: "unmounted"          // unmounted | mounted | out
    property real cy: 0
    property real pxmm: Geo.PX_PER_MM["24"]
    property bool compact: false
    property var rail: Geo.railGeometry(Settings.railInset, Settings.railWidth)
    property real outX: 0                      // "out": leading-edge x beside the card
    property bool locked: false
    property bool cracked: false
    property real clipRight: rail.maxX         // the object never reaches past the rail margin
    property bool animate: Settings.reading.transitions === "full"
    // artVersion: set to SkinStore.version by the user of this item, so your own device art
    // (docs/SKINS.md) re-lay the object out and repaint when they change.
    property int artVersion: 0
    readonly property var geometry: Geo.motion(kind, cy, pxmm, rail, compact, artVersion)
    readonly property var span: Geo.extent(kind, pose, cy, pxmm, rail, compact, artVersion)
    onArtVersionChanged: repaint()
    property real swing: pose === "unmounted" ? 0 : 1
    readonly property bool moving: swing > 0.001 && swing < 0.999
    Behavior on swing { enabled: root.animate; NumberAnimation { duration: 320; easing.type: Easing.InOutCubic } }
    opacity: pose === "unmounted" ? 0.55 : 1
    Behavior on opacity { enabled: root.animate; NumberAnimation { duration: 200 } }
    clip: true
    function bakeInto(ctx, W, H, raster, which) {
        // The skin's images must be loaded in this canvas; they stay loaded while the device is
        // shown (the object repaints on every pose). If they fail, the SSD's images stand in.
        const urls = Art.imageUrls(root.kind), ready = raster.images(urls), failed = ready === "failed";
        if (ready === "loading") { ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.clearRect(0, 0, W, H); return; }
        Art.bake(ctx, {kind: root.kind, builtin: failed, pose: which, cy: root.cy, pxmm: root.pxmm, rail: root.rail, compact: root.compact, outX: root.outX,
                       locked: root.locked, cracked: root.cracked, D: raster.dpr, gc: raster.grain, W: W, H: H, sealAt: [root.rail.maxX - 16, root.cy]});
    }
    RasterCanvas {
        id: rest
        anchors.fill: parent
        visible: !root.moving
        onPainting: function(ctx, W, H) { root.bakeInto(ctx, W, H, rest, root.pose); }
    }
    RasterCanvas {
        id: turning
        anchors.fill: parent
        visible: root.moving
        transform: [
            Rotation { origin.x: root.geometry.originX; origin.y: root.geometry.originY; angle: root.geometry.angle * root.swing },
            Translate { x: root.geometry.dx * root.swing; y: root.geometry.dy * root.swing }
        ]
        onPainting: function(ctx, W, H) { root.bakeInto(ctx, W, H, turning, "unmounted"); }
    }
    function repaint() { rest.repaint(); turning.repaint(); }
    onKindChanged: repaint()
    onPoseChanged: rest.repaint()
    onCyChanged: repaint()
    onPxmmChanged: repaint()
    onCompactChanged: repaint()
    onLockedChanged: repaint()
    onCrackedChanged: repaint()
    onOutXChanged: rest.repaint()
}
