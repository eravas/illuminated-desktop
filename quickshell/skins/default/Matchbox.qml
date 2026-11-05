import QtQuick
import qs.skin
// The matchbox: deals Power.
SkinItem {
    size: [17, 13]; anchor: [16, 6.5]
    hand: "power"
    tag: Actions.label("deal:power")
    onClicked: run("deal:power")
    FrameImage { file: Qt.resolvedUrl("elements/matchbox.png") }
}
