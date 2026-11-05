import QtQuick
import qs.skin
// A Do Not Disturb button after the dock's windows: a stamp with a red dot while it is on.
DockLayout {
    after: [
        SkinItem {
            objectName: "quiet"
            units: "px"; size: [30, 30]; anchor: [15, 15]
            tag: "Do not disturb"
            onClicked: run("dnd")
            FrameImage { file: Qt.resolvedUrl("elements/quiet.png"); count: 2; frame: ShellState.dnd ? 1 : 0 }
        }
    ]
}
