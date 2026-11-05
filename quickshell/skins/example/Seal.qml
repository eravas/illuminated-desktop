import QtQuick
import qs.skin
// A wax seal: deals this skin's Desk hand (Cards.qml). It turns and swells under the pointer.
SkinItem {
    id: seal
    units: "px"; size: [26, 26]; anchor: [13, 13]; place: "center"
    tag: "Desk"
    onClicked: run("deal:desk")
    FrameImage {
        file: Qt.resolvedUrl("elements/seal.png")
        transformOrigin: Item.Center
        rotation: seal.hovered ? -12 : 0
        scale: seal.hovered ? 1.08 : 1
        Behavior on rotation { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
    }
}
