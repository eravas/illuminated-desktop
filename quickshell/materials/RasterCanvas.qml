import QtQuick
import QtQuick.Window
import Quickshell
import "../config"
// A Canvas whose backing image is in device pixels, so dither cells land on the output's
// pixel grid at any scale. Painted on demand and then a static texture: nothing redraws
// once settled. `coalesce` (ms) limits repaint rate while a level is being dragged.
// (3) Fractional scale: Qt's own Canvas DPR handling is assumed not to resample
// putImageData; check crispness on a 1.25× output.
Item {
    id: root
    property real dpr: Screen.devicePixelRatio > 0 ? Screen.devicePixelRatio : 1
    readonly property int grain: Math.max(1, Math.round(Settings.option("pixel.logical") * dpr))
    readonly property int deviceWidth: Math.max(1, Math.round(width * dpr))
    readonly property int deviceHeight: Math.max(1, Math.round(height * dpr))
    property int coalesce: 0
    // ILLUMINATED_PROFILE=1 logs each paint's duration: "paint <kind> <w>x<h> <ms>".
    property string kind: objectName || (parent ? String(parent).split("_QML")[0].split("(")[0] : "?")
    // Handlers: onPainting: function(ctx, w, h) { … } — w, h in device px.
    signal painting(var ctx, int w, int h)
    // Images for drawImage (skin art). One rule for every user: images(urls) is "ready",
    // "loading" (this canvas repaints when they arrive) or "failed"; build-once-then-release
    // goes through withImages(), which keeps nothing decoded after it returns.
    function images(urls) { return imagesFailed(urls) ? "failed" : loadImages(urls) ? "ready" : "loading"; }
    function withImages(urls, build, keep) {
        const state = images(urls);
        if (state !== "ready") return {state: state, value: null};
        const value = build();
        if (!keep) unloadImages(urls);
        return {state: state, value: value};
    }
    function loadImages(urls) { let all = true; for (const u of urls) if (u && !canvas.isImageLoaded(u)) { all = false; if (!canvas.isImageLoading(u)) canvas.loadImage(u); } return all; }
    function imagesFailed(urls) { return urls.some(u => u && canvas.isImageError(u)); }
    function unloadImages(urls) { for (const u of urls) if (u) canvas.unloadImage(u); }
    function repaint() { if (coalesce > 0) { if (!throttle.running) throttle.start(); } else canvas.requestPaint(); }
    onDprChanged: canvas.requestPaint()
    onGrainChanged: canvas.requestPaint()
    Canvas {
        id: canvas
        width: root.deviceWidth; height: root.deviceHeight
        scale: 1 / root.dpr
        transformOrigin: Item.TopLeft
        smooth: false
        renderTarget: Canvas.Image
        renderStrategy: Canvas.Cooperative
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onImageLoaded: root.repaint()
        onPaint: {
            if (root.width <= 0 || root.height <= 0) return;
            const t0 = Profile.enabled ? Date.now() : 0;
            const ctx = getContext("2d");
            MaterialFields.ensure(root, ctx);     // the skin's material images, once per skin
            const t1 = Profile.enabled ? Date.now() : 0;
            root.painting(ctx, width, height);
            if (Profile.enabled) Profile.paint(root.kind, width, height, t1 - t0, Date.now() - t1);
        }
    }
    Component.onCompleted: if (Profile.enabled) Profile.alive++
    Component.onDestruction: if (Profile.enabled) Profile.alive--
    Connections { target: MaterialFields; function onVersionChanged() { canvas.requestPaint(); } }
    Timer { id: throttle; interval: root.coalesce; onTriggered: canvas.requestPaint() }
}
