.pragma library
// Finished canvas images by key, shared by every canvas (QML shares .pragma library modules).
// A canvas that paints the same thing again (Qt repaints a Canvas.Image when its window is
// exposed; a mode switched back; a second sheet of the same size) puts the cached ImageData
// instead of running the painter. Least recently used entries go past `limit`.
var entries = {}, order = [], limit = 8;
function get(key) {
    var e = entries[key];
    if (!e) return null;
    order.splice(order.indexOf(key), 1); order.push(key);
    return e;
}
function put(key, image) {
    if (!entries[key]) order.push(key);
    entries[key] = image;
    while (order.length > limit) delete entries[order.shift()];
}
