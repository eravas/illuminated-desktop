import QtQuick
// A polygon hit area for SkinItem.hitShape, in the item's units, grown by `pad` so thin objects
// (the nib, the paperclip) stay easy to hit.
QtObject {
    property var points: []                // [[x, y], …]
    property real pad: 0
    function bounds() {
        if (!points.length) return [0, 0, 0, 0];
        let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity;
        for (const q of points) { x0 = Math.min(x0, q[0]); y0 = Math.min(y0, q[1]); x1 = Math.max(x1, q[0]); y1 = Math.max(y1, q[1]); }
        return [x0 - pad, y0 - pad, x1 - x0 + 2 * pad, y1 - y0 + 2 * pad];
    }
    function inside(x, y) {
        let c = false;
        for (let i = 0, j = points.length - 1; i < points.length; j = i++) {
            const a = points[i], b = points[j];
            if ((a[1] > y) !== (b[1] > y) && x < (b[0] - a[0]) * (y - a[1]) / (b[1] - a[1]) + a[0]) c = !c;
        }
        return c;
    }
    function edge(px, py) {   // distance to the nearest edge
        let d = Infinity;
        for (let i = 0, j = points.length - 1; i < points.length; j = i++) {
            const a = points[j], b = points[i], vx = b[0] - a[0], vy = b[1] - a[1], l = vx * vx + vy * vy || 1;
            const t = Math.max(0, Math.min(1, ((px - a[0]) * vx + (py - a[1]) * vy) / l)), ex = a[0] + t * vx - px, ey = a[1] + t * vy - py;
            d = Math.min(d, Math.sqrt(ex * ex + ey * ey));
        }
        return d;
    }
    function contains(p) { return inside(p.x, p.y) || (pad > 0 && edge(p.x, p.y) <= pad); }
}
