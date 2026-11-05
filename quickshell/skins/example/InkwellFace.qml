import QtQuick
import qs.skin
// The inkwell card's face: art drawn for a 154 px wide card, scaled to the card; the cork
// deals Levels.
Item {
    id: face
    property var card: null
    readonly property real k: width / 154
    Image {
        anchors.fill: parent
        source: Qt.resolvedUrl(face.k * (face.card ? face.card.Window.devicePixelRatio || 1 : 1) > 1.25 ? "elements/inkwell-face-2x.png" : "elements/inkwell-face.png")
        smooth: true
    }
    SkinItem {
        objectName: "cork"
        units: "px"; shadowMargin: 0
        x: 57 * face.k; y: 20 * face.k; size: [40 * face.k, 40 * face.k]
        tag: "Levels"
        onClicked: run("deal:levels")
    }
}
