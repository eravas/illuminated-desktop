import QtQuick
import Quickshell
import "../theme"
import "../config"
// The hover tag (DESIGN-SYSTEM.md §3.13): a short Alegreya label on vellum beside the rail or
// under the dock. A popup surface, so it is not clipped by the narrow rail window.
// show(item, text, side): side "right" (rail) or "below" (dock).
PopupWindow {
    id: root
    property var host: null
    property string text: ""
    property string side: "right"
    property real ax: 0
    property real ay: 0
    color: "transparent"
    visible: false
    anchor.window: host
    // Default edges/gravity: the tag's top-left sits at (ax, ay) in the host window.
    anchor.rect.x: ax; anchor.rect.y: ay; anchor.rect.width: 1; anchor.rect.height: 1
    implicitWidth: label.implicitWidth + 20
    implicitHeight: label.implicitHeight + 12
    function show(item, text, side) {
        if (!item || !text || !host) { hide(); return; }
        root.side = side || "right"; root.text = text;
        const p = item.mapToItem(null, root.side === "right" ? item.width + 6 : item.width / 2, root.side === "right" ? item.height / 2 : item.height + 8);
        ax = p.x; ay = p.y - (root.side === "right" ? implicitHeight / 2 : 0);
        if (root.side !== "right") ax -= implicitWidth / 2;
        if (visible && typeof anchor.updateAnchor === "function") anchor.updateAnchor();   // the anchor is computed when shown
        visible = true;
    }
    function hide() { visible = false; }
    Rectangle {
        anchors.fill: parent
        color: Theme.paper
        border.color: Theme.edge; border.width: 1
        Text {
            id: label
            anchors.centerIn: parent
            text: root.text; textFormat: Text.PlainText
            font.family: Theme.serifFamily; font.pixelSize: Math.round(14 * Theme.typeScale)
            color: Theme.ink
        }
    }
}
