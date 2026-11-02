import QtQuick
import "../config"
import "../materials"
import "Skin.js" as Skin
import "Compose.js" as Compose
import "../materials/ArtLayers.js" as Px
// One skin element on screen (docs/SKINS.md, "Elements"): its look for the current shell values,
// its regions, frame and transform animations, active areas, hover tags and triggers.
//
// Public surface:
//   elementId   which element of SkinStore.manifest.elements
//   pxmm        logical px per mm (life size); px-unit elements ignore it
//   tag         a rail/dock Tag for hover labels (optional)
//   context     extra for Actions.run (e.g. {screen}); the item's screen y is added on trigger
//   extra       values merged over ShellState.values (e.g. a dock entry's own state)
//   fitWidth    scale the element to this width in logical px (cards), instead of pxmm
//   anchorX/Y   (read-only) the element's anchor in this item's logical px, for placement
//   trigger(kind, target) / targetAt(x, y)  for hosts that take the pointer themselves (cards)
//   triggered(action, target)  emitted after a trigger ran (target "#" or a region id)
// The item is the element box plus a margin for the shadow; place it by anchorX/anchorY.
Item {
    id: root
    property string elementId: ""
    property real pxmm: 3.6
    property var tag: null
    property var context: ({})
    property var extra: ({})
    // Fit the element's width to this many logical px (cards); 0: life size / px units.
    property real fitWidth: 0
    signal triggered(string action, string target)

    readonly property var manifest: SkinStore.manifest
    readonly property var element: SkinStore.element(elementId)
    readonly property bool valid: !!element && !!element.size
    readonly property real unitScale: fitWidth > 0 && valid ? fitWidth / element.size[0] : Skin.scaleFor(Skin.unitsOf(manifest, element), pxmm)
    readonly property int margin: valid && element.shadow === false ? 0 : 6
    readonly property var anchorUnits: valid && element.anchor ? element.anchor : [0, 0]
    readonly property real anchorX: margin + anchorUnits[0] * unitScale
    readonly property real anchorY: margin + anchorUnits[1] * unitScale
    readonly property bool motion: Settings.reading.transitions === "full"
    implicitWidth: valid ? element.size[0] * unitScale + 2 * margin : 0
    implicitHeight: valid ? element.size[1] * unitScale + 2 * margin : 0
    visible: valid && Skin.test(element.visibleWhen, values)

    // ── values ──
    readonly property var values: {
        const s = {}, base = ShellState.values;
        for (const k in base) s[k] = base[k];
        for (const k2 in extra) s[k2] = extra[k2];
        return s;
    }
    readonly property var uses: valid ? Skin.sources(element) : []
    readonly property string stateKey: JSON.stringify(uses.map(s => values[s]))
    property var lastValues: ({})
    onStateKeyChanged: {
        const changed = [];
        for (const s of uses) if (lastValues[s] !== values[s]) changed.push(s);
        const next = {}; for (const s2 of uses) next[s2] = values[s2]; lastValues = next;
        for (const c of changed) play("change:" + c, "#");
        raster.repaint();
    }
    // Regions in force: visible, and at least one of their triggers can act.
    function live(r) {
        if (!Skin.test(r.visibleWhen, values)) return false;
        const t = r.triggers || {}, names = Object.keys(t);
        return names.length === 0 || names.some(n => Actions.available(t[n]));
    }
    readonly property var liveRegions: valid ? (element.regions || []).filter(r => live(r)) : []
    onLiveRegionsChanged: raster.repaint()

    // ── animations ──
    // Frame animations override the look's frame (element "#" or a region id) until they end;
    // tweens move the pose. Frames are composed once per frame and cached.
    property var frameOverride: ({})     // target → {anim, list, start}
    property var poseNow: Skin.pose({})
    property var tween: null             // {from, anim, start}
    function play(event, target) {
        const owner = target === "#" ? element : (element.regions || []).find(r => r.id === target);
        if (!owner) return;
        for (const a of Skin.animationsFor(owner, event)) {
            if (a.frames) {
                const list = Skin.frames(manifest, a.frames);
                if (!list.length) continue;
                const o = Object.assign({}, frameOverride);
                if (!motion) { if (a.mode === "hold") o[target] = {anim: a, list: list, start: -1e9}; else delete o[target]; }
                else o[target] = {anim: a, list: list, start: Date.now()};
                frameOverride = o;
            } else if (a.tween && target === "#") {
                if (!motion) { poseNow = Skin.pose(a.tween); tween = null; }
                else tween = {from: poseNow, anim: a, start: Date.now()};
            }
        }
        clock.running = Object.keys(frameOverride).length > 0 || tween !== null;
        raster.repaint();
    }
    function currentFrame(target) {
        const f = frameOverride[target];
        if (!f) return null;
        const i = Skin.frameAt(f.anim, f.list.length, Date.now() - f.start);
        return i < 0 ? null : f.list[i];
    }
    Timer {
        id: clock
        interval: 16; repeat: true
        onTriggered: {
            const now = Date.now();
            if (root.tween) {
                const t = now - root.tween.start, d = root.tween.anim.duration === undefined ? 150 : root.tween.anim.duration;
                root.poseNow = Skin.tweenAt(root.tween.from, root.tween.anim, t);
                if (t >= d) root.tween = null;
            }
            const o = Object.assign({}, root.frameOverride);
            let changed = false;
            for (const k in o) {
                const f = o[k], n = f.list.length;
                if (Skin.frameAt(f.anim, n, now - f.start) < 0) { delete o[k]; changed = true; }
                else changed = true;   // a new frame may be due
            }
            if (changed) { root.frameOverride = o; raster.repaint(); }
            running = Object.keys(root.frameOverride).length > 0 || root.tween !== null;
        }
    }
    transform: [
        Translate { x: root.poseNow.x * root.unitScale; y: root.poseNow.y * root.unitScale },
        Rotation { origin.x: root.anchorX; origin.y: root.anchorY; angle: root.poseNow.rotate },
        Scale { origin.x: root.anchorX; origin.y: root.anchorY; xScale: root.poseNow.scale; yScale: root.poseNow.scale }
    ]
    opacity: poseNow.opacity

    // ── painting ──
    // Caches: layers (an image ref drawn into a rect, per size) and finished frames (per look).
    property var layers: ({})
    property var finished: ({})
    property var finishedOrder: []
    property var hitMaps: ({})           // "alpha" → element; "r:<id>" → region; "mask:<name>[:<id>]"
    property var geo: null
    readonly property string cacheKey: SkinStore.version + "/" + elementId + "/" + width + "x" + height + "@" + raster.dpr
    onCacheKeyChanged: { layers = {}; finished = {}; finishedOrder = []; hitMaps = {}; raster.repaint(); }
    Component.onCompleted: { play("load", "#"); }
    RasterCanvas {
        id: raster
        anchors.fill: parent
        coalesce: 33
        onPainting: function(ctx, W, H) {
            if (!root.valid) { ctx.clearRect(0, 0, W, H); return; }
            const urls = Skin.files(root.manifest, root.element).map(f => SkinStore.url(f));
            const ready = raster.images(urls);
            if (ready === "failed") console.warn("illuminated skin:", root.elementId, "has images that do not load");
            if (ready !== "ready") { ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.clearRect(0, 0, W, H); return; }   // repaints on load
            const g = Compose.geometry(root.element.size, root.unitScale, root.margin, raster.dpr);
            root.geo = g;
            const lk = Skin.look(root.element, root.values);
            const frame = root.currentFrame("#");
            const regions = root.liveRegions.map(r => ({id: r.id, rect: r.rect || null, look: Skin.look(r, root.values), frame: root.currentFrame(r.id)}));
            const level = lk.ink ? Math.round((Number(root.values[lk.ink.source]) || 0) * 100) : -1;
            const key = JSON.stringify([lk, frame, regions.map(r => [r.id, r.look, r.frame]), level, lk.ink && lk.ink.bands ? Skin.test(lk.ink.bands, root.values) : 0,
                                        (lk.markers || []).map(m => Skin.test(m.when, root.values))]);
            let done = root.finished[key];
            if (!done) {
                const layer = (ref, rect) => root.layer(ctx, g, ref, rect);
                const px = Compose.compose({manifest: root.manifest, g: g, look: lk, state: root.values, layer: layer, frame: frame, regions: regions, inks: root.manifest.inks});
                Compose.finish(px, g, raster.grain, {dither: root.element.dither !== false, shadow: root.element.shadow !== false});
                done = {px: px, alpha: Compose.alpha(px, g.W, g.H)};
                const f = root.finished; f[key] = done;
                const order = root.finishedOrder; order.push(key);
                if (order.length > 48) delete f[order.shift()];   // frames of a few animations, at most
                for (const r of regions) root.regionHit(ctx, g, r);
                [].concat(root.element.hit || []).forEach(h => {
                    const m = h && h.mask ? Skin.image(root.manifest, h.mask) : null;
                    if (m) root.hitMaps["mask:" + h.mask + ":"] = Px.hitMap(root.layer(ctx, g, m, null), g.W, g.H, 0);
                });
            }
            root.hitMaps["alpha"] = done.alpha;
            const img = ctx.createImageData(W, H);
            Px.copyInto(img.data, done.px);
            ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.clearRect(0, 0, W, H);
            ctx.putImageData(img, 0, 0, 0, 0, W, H);
        }
    }
    // An image ref drawn into rect (element units; null = the element box), cached per size.
    function layer(ctx, g, ref, rect) {
        const key = ref.file + "|" + (ref.rect || "") + "|" + (rect || "");
        if (layers[key]) return layers[key];
        const r = rect || [0, 0, element.size[0], element.size[1]];
        const px = Px.rasterise(ctx, g.W, g.H, g.D, SkinStore.url(ref.file), g.margin + r[0] * g.scale, g.margin + r[1] * g.scale, r[2] * g.scale, r[3] * g.scale, 0, ref.rect);
        layers[key] = px;
        return px;
    }
    // A region's own drawn pixels, grown by its pad, for {alpha: true} hits on it.
    function regionHit(ctx, g, r) {
        const ref = Compose.frameOf(manifest, r.look, values, r.frame);
        const src = (element.regions || []).find(x => x.id === r.id) || {};
        hitMaps["r:" + r.id] = ref ? Px.hitMap(layer(ctx, g, ref, r.rect), g.W, g.H, Math.round((src.pad === undefined ? 4 : src.pad) * g.D)) : new Uint8Array(g.W * g.H);
        [].concat(src.hit || []).forEach(h => {
            if (!h || !h.mask) return;
            const m = Skin.image(manifest, h.mask);
            if (m) hitMaps["mask:" + h.mask + ":" + r.id] = Px.hitMap(layer(ctx, g, m, r.rect), g.W, g.H, 0);
        });
    }
    function alphaAt(kind, ux, uy, regionId) {
        if (!geo) return false;
        const p = Compose.toDevice(geo, [ux, uy]), x = Math.round(p[0]), y = Math.round(p[1]);
        if (x < 0 || y < 0 || x >= geo.W || y >= geo.H) return false;
        const map = kind === "alpha" ? hitMaps[regionId ? "r:" + regionId : "alpha"] : hitMaps[kind + ":" + (regionId || "")] || hitMaps[kind];
        return !!map && map[y * geo.W + x] > 0;
    }

    // ── input ──
    function targetAt(x, y) {
        if (!valid) return "";
        const u = [(x - margin) / unitScale, (y - margin) / unitScale];
        // Regions without triggers are decoration (they draw, but clicks pass through them).
        return Skin.hit({regions: liveRegions.filter(r => r.triggers), hit: element.hit}, u[0], u[1], (k, ux, uy, rid) => alphaAt(k, ux, uy, rid), null);
    }
    function owner(target) { return target === "#" ? element : liveRegions.find(r => r.id === target) || null; }
    function tagText(target) {
        const o = owner(target);
        if (!o) return "";
        if (o.tag) return Skin.format(o.tag, values);
        const t = o.triggers || {};
        return Actions.label(t.click || t.rightClick || t.scrollUp || "");
    }
    function trigger(kind, target) {
        const o = owner(target);
        const action = o && o.triggers ? o.triggers[kind] : "";
        if (!action) return false;
        const ctx = Object.assign({}, context, {y: mapToItem(null, 0, height / 2).y});
        if (Actions.run(action, ctx)) { play("click", target); triggered(action, target); return true; }
        return false;
    }
    property string hovered: ""
    function track(x, y) {
        const t = targetAt(x, y);
        if (t === hovered) return;
        if (hovered) play("hoverOut", hovered);
        hovered = t;
        if (t) play("hoverIn", t);
        if (tag) { if (t && tagText(t)) tag.show(root, tagText(t), "right"); else tag.hide(); }
    }
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: root.hovered && root.owner(root.hovered) && root.owner(root.hovered).triggers ? Qt.PointingHandCursor : Qt.ArrowCursor
        onPositionChanged: mouse => root.track(mouse.x, mouse.y)
        onExited: { if (root.hovered) root.play("hoverOut", root.hovered); root.hovered = ""; if (root.tag) root.tag.hide(); }
        onPressed: mouse => { const t = root.targetAt(mouse.x, mouse.y); if (t) root.play("press", t); else mouse.accepted = false; }
        onReleased: mouse => { const t = root.targetAt(mouse.x, mouse.y); if (t) root.play("release", t); }
        onClicked: mouse => {
            const t = root.targetAt(mouse.x, mouse.y);
            if (!t) return;
            root.trigger(mouse.button === Qt.RightButton ? "rightClick" : mouse.button === Qt.MiddleButton ? "middleClick" : "click", t);
        }
        onDoubleClicked: mouse => { const t = root.targetAt(mouse.x, mouse.y); if (t) root.trigger("doubleClick", t); }
        onWheel: wheel => {
            const t = root.targetAt(wheel.x, wheel.y);
            if (!t || !root.trigger(wheel.angleDelta.y > 0 ? "scrollUp" : "scrollDown", t)) wheel.accepted = false;
        }
    }
    // Keyboard and assistive tech: the element and each live region are named buttons.
    Accessible.role: Accessible.Button
    Accessible.name: tagText("#")
    activeFocusOnTab: valid && !!element.triggers
    Keys.onReturnPressed: trigger("click", "#")
    Keys.onSpacePressed: trigger("click", "#")
    Repeater {
        model: root.liveRegions.filter(r => r.triggers)
        Item {
            required property var modelData
            readonly property var r: modelData.rect || (root.valid ? [0, 0, root.element.size[0], root.element.size[1]] : [0, 0, 0, 0])
            x: root.margin + r[0] * root.unitScale; y: root.margin + r[1] * root.unitScale
            width: Math.max(24, r[2] * root.unitScale); height: Math.max(24, r[3] * root.unitScale)
            Accessible.role: Accessible.Button
            Accessible.name: root.tagText(modelData.id)
            activeFocusOnTab: !!modelData.triggers
            Keys.onReturnPressed: root.trigger("click", modelData.id)
            Keys.onSpacePressed: root.trigger("click", modelData.id)
        }
    }
}
