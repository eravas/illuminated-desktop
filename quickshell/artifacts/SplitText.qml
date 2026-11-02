import QtQuick
import "CardModel.js" as CardModel
import "../theme"
// Live text inked by what lies beneath it: over the wash it takes the wash's
// ink, elsewhere `ink`. Two clipped copies meet exactly at the wash boundary.
// originX/originY: this item's position in face coordinates.
Item {
    id: root
    property string text
    property color ink
    property var wash: null
    property real faceWidth
    property real faceHeight
    property real originX: 0
    property real originY: 0
    property string family
    property real pixelSize: 16
    property bool bold: Theme.cardBold     // blackletter faces have a single weight
    property int horizontalAlignment: Text.AlignLeft
    implicitWidth: probe.implicitWidth
    implicitHeight: probe.implicitHeight
    readonly property var area: CardModel.washRect(wash, faceWidth, faceHeight)
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
