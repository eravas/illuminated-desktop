// Pure layout policy. Rotated axis-aligned bounds, not unrotated card heights.
function clamp(value, low, high) { return Math.max(low, Math.min(high, value)); }
function bounds(width, angle, ratio) {
    const a = Math.abs(angle) * Math.PI / 180, height = width / (ratio || 5 / 7);
    return {width: width * Math.cos(a) + height * Math.sin(a), height: height * Math.cos(a) + width * Math.sin(a)};
}
// The launcher spread (DESIGN.md §8): one vellum sheet centred in the space right of the rail
// and under a permanent dock, unfurling flat from its left edge. progress 0..1 (no curl, no
// second centring phase). left/top: space held by the rail and dock.
function spread(width, height, progress, options) {
    const cfg = options || {}, left = cfg.left || 0, top = cfg.top || 0;
    const sheetWidth = Math.min(cfg.width || 820, Math.max(1, width - left - 32));
    const sheetHeight = Math.min(cfg.height || 600, Math.max(1, height - top - 48));
    return {width: sheetWidth, height: sheetHeight,
        x: Math.round(left + (width - left - sheetWidth) / 2),
        y: Math.round(top + (height - top - sheetHeight) / 2),
        reveal: clamp(progress, 0, 1) * sheetWidth};
}
// A hand dealt sideways out of the left rail (DESIGN.md §6, §8): cards in a row to the right
// of the rail, vertically centred on the initial that dealt them, travelling in from the left
// edge; the leading (rightmost) card travels farthest. left/top: space taken by the rail and a
// permanent dock. Returns cards with offscreenX (start position) instead of offscreenY.
function dealLeft(screenWidth, screenHeight, triggerY, items, page, left, top, options) {
    const cfg = options || {}, margin = cfg.margin || 16, gap = cfg.gap || 24, lift = cfg.lift || 6;
    const aligned = !!cfg.aligned, angle = aligned ? 0 : cfg.rotation === undefined ? 4 : cfg.rotation;
    const snap = v => aligned ? Math.round(v) : v;
    const kinds = Array.isArray(items) ? items : Array.from({length: items}, () => "standard");
    const dims = kinds.map(k => { const landscape = !!(k && k.landscape); return {ratio: landscape ? 7 / 5 : 5 / 7, preferred: landscape ? (cfg.landscapeWidth || 248) : (cfg.cardWidth || 154)}; });
    let available = Math.max(1, screenWidth - left - margin * 2);
    const minWidth = dims.reduce((max, d) => Math.max(max, bounds(d.preferred * .65, angle, d.ratio).width), 1);
    let capacity = Math.max(1, Math.min(3, Math.floor((available + gap) / (minWidth + gap))));
    const pages = Math.max(1, Math.ceil(kinds.length / capacity)), current = clamp(page, 0, pages - 1);
    const group = dims.slice(current * capacity, (current + 1) * capacity);
    const full = group.map(d => bounds(d.preferred, angle, d.ratio));
    const total = full.reduce((sum, b) => sum + b.width, 0);
    const tallest = full.reduce((max, b) => Math.max(max, b.height), 1);
    const usableHeight = Math.max(1, screenHeight - top - 2 * margin - lift - (pages > 1 ? 44 : 0));
    const scale = Math.max(.01, Math.min(1, usableHeight / tallest, (available - Math.max(0, group.length - 1) * gap) / Math.max(1, total)));
    const boxes = full.map(b => ({width: b.width * scale, height: b.height * scale}));
    const maxHeight = boxes.reduce((max, b) => Math.max(max, b.height), 1), maxWidth = boxes.reduce((max, b) => Math.max(max, b.width), 1);
    const lane = clamp(triggerY, top + margin + lift + maxHeight / 2, screenHeight - margin - (pages > 1 ? 44 : 0) - maxHeight / 2);
    const cards = [];
    let cursor = left + margin;
    for (let i = 0; i < group.length; i++) {
        const width = group[i].preferred * scale, height = width / group[i].ratio;
        cards.push({index: current * capacity + i, x: snap(cursor + (boxes[i].width - width) / 2), y: snap(lane - height / 2),
            width: width, height: height, ratio: group[i].ratio, angle: aligned ? 0 : i % 2 ? -angle : angle, offscreenX: -maxWidth - width / 2});
        cursor += boxes[i].width + gap;
    }
    return {cards: cards, pages: pages, page: current, lane: lane, capacity: capacity, axis: "x"};
}
