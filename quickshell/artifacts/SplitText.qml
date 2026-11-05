import QtQuick
import "CardModel.js" as CardModel
import "../theme"
// Live text inked by what lies beneath it: over the wash it takes the wash's
// ink, elsewhere the face's ink. Two clipped copies meet exactly at the wash boundary.
// face: the card face this is printed on, {item, ink, wash}; where the text sits on it is
// mapped, not passed in, and follows layout changes.
Item {
    id: root
    property string text
    property var face: null
    readonly property color ink: face ? face.ink : "transparent"
    readonly property var wash: face ? face.wash || null : null
    property string family: Theme.cardFamily
    property real pixelSize: 16
    property bool bold: Theme.cardBold     // blackletter faces have a single weight
    property int horizontalAlignment: Text.AlignLeft
    // Position on the face. Recomputed when this item, an ancestor up to the face, or the
    // face itself moves or resizes.
    property real originX: 0
    property real originY: 0
    function place() {
        if (!face || !face.item) return;
        const p = mapToItem(face.item, 0, 0);
        originX = p.x; originY = p.y;
    }
    property var watched: []
    function watch() {
        unwatch();
        const items = [];
        for (let a = root; a && face && a !== face.item; a = a.parent) items.push(a);
        if (face && face.item) items.push(face.item);
        for (const a of items) { a.xChanged.connect(root.schedule); a.yChanged.connect(root.schedule); a.widthChanged.connect(root.schedule); a.heightChanged.connect(root.schedule); }
        watched = items;
        place();
    }
    function unwatch() { for (const a of watched) { a.xChanged.disconnect(root.schedule); a.yChanged.disconnect(root.schedule); a.widthChanged.disconnect(root.schedule); a.heightChanged.disconnect(root.schedule); } watched = []; }
    function schedule() { Qt.callLater(root.place); }
    onFaceChanged: Qt.callLater(root.watch)
    onParentChanged: Qt.callLater(root.watch)
    Component.onCompleted: watch()
    Component.onDestruction: unwatch()
    implicitWidth: probe.implicitWidth
    implicitHeight: probe.implicitHeight
    readonly property var area: face && face.item ? CardModel.washRect(wash, face.item.width, face.item.height) : CardModel.washRect(null, 0, 0)
    // Wash region in local coordinates. Washes start at the left or bottom edge,
    // so the remaining region is always a single rectangle.
    readonly property real washLeft: Math.max(0, area.x - originX)
    readonly property real washRight: Math.min(width, area.x + area.width - originX)
    readonly property real washTop: Math.max(0, area.y - originY)
    readonly property real washBottom: Math.min(height, area.y + area.height - originY)
    readonly property bool vertical: !!wash && wash.axis === "y"
    Text {
        id: probe
        visible: false
        text: root.text; textFormat: Text.PlainText
        font.family: root.family; font.pixelSize: root.pixelSize; font.bold: root.bold
    }
    Item {   // over cardstock
        id: offPart
        clip: true
        x: !root.wash || root.vertical ? 0 : Math.max(0, root.washRight)
        y: 0
        width: !root.wash || root.vertical ? root.width : Math.max(0, root.width - x)
        height: !root.wash || !root.vertical ? root.height : Math.max(0, Math.min(root.height, root.washTop))
        Text {
            x: -offPart.x; y: -offPart.y; width: root.width; height: root.height
            text: root.text; textFormat: Text.PlainText
            font.family: root.family; font.pixelSize: root.pixelSize; font.bold: root.bold
            color: root.ink
            elide: Text.ElideRight
            horizontalAlignment: root.horizontalAlignment
            verticalAlignment: Text.AlignVCenter
        }
    }
    Item {   // over the wash
        id: onPart
        clip: true
        visible: !!root.wash
        x: root.washLeft; y: root.washTop
        width: Math.max(0, root.washRight - root.washLeft)
        height: Math.max(0, root.washBottom - root.washTop)
        Text {
            x: -onPart.x; y: -onPart.y; width: root.width; height: root.height
            text: root.text; textFormat: Text.PlainText
            font.family: root.family; font.pixelSize: root.pixelSize; font.bold: root.bold
            color: root.wash ? root.wash.ink : "transparent"
            elide: Text.ElideRight
            horizontalAlignment: root.horizontalAlignment
            verticalAlignment: Text.AlignVCenter
        }
    }
}
