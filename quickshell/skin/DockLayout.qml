import QtQuick
// The dock's skin objects (docs/SKINS.md, "DockChrome.qml"): `before` and `after` the windows.
// The dock sets `dock` when it loads this; every SkinItem in either list gets this as its host.
Item {
    id: root
    property list<Item> before
    property list<Item> after
    property var dock: null                // set by rail/Dock.qml
    readonly property real pxmm: dock ? dock.pxmm : 0
    readonly property var screen: dock ? dock.screen : null
    readonly property var tag: dock ? dock.tag : null
    readonly property string tagSide: "below"
    function handShown(name) { return true; }
    function adopt(item) { if (!item) return; if (item.host !== undefined) item.host = root; for (const c of item.children || []) adopt(c); }
    onDockChanged: { for (const i of before) adopt(i); for (const j of after) adopt(j); }
}
