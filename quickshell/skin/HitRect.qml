import QtQuick
// A rectangular hit area for SkinItem.hitShape, in the item's units.
QtObject {
    property var rect: [0, 0, 0, 0]       // x, y, width, height
    function bounds() { return rect; }
    function contains(p) { return p.x >= rect[0] && p.y >= rect[1] && p.x <= rect[0] + rect[2] && p.y <= rect[1] + rect[3]; }
}
