import QtQuick
// A round hit area for SkinItem.hitShape, in the item's units.
QtObject {
    property var center: [0, 0]
    property real radius: 0
    function bounds() { return [center[0] - radius, center[1] - radius, 2 * radius, 2 * radius]; }
    function contains(p) { const dx = p.x - center[0], dy = p.y - center[1]; return dx * dx + dy * dy <= radius * radius; }
}
