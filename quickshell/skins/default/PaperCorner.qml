import QtQuick
import qs.skin
// The paper in the rail's foot: handwriting for each unread notification (up to six lines);
// a click deals Correspondence. The paperclip on it (while clipboard history is on) opens the
// clipboard sheet.
SkinItem {
    id: paper
    size: [18, 22]; anchor: [0, 22]
    tag: Actions.label("notifications")
    onClicked: run("notifications")
    readonly property bool clipShown: Actions.available("clipboard")
    FrameImage { file: Qt.resolvedUrl("elements/paper.png"); count: 14; frame: Math.min(6, ShellState.unread) + (paper.clipShown ? 7 : 0) }
    SkinItem {
        objectName: "paperclip"
        visible: paper.clipShown
        x: -1.31 * paper.unit; y: 5.53 * paper.unit
        size: [12, 12]; anchor: [0, 0]
        tag: "Clipboard history"
        hitShape: HitPolygon {
            pad: 1
            points: [[3.66, 2.14], [3.8, 1.73], [3.94, 1.45], [4.22, 1.18], [4.49, 1.04], [5.19, 1.04], [5.46, 1.18], [5.74, 1.45], [6.02, 2.01], [6.29, 2.83], [7.4, 6.43], [8.09, 8.78], [8.09, 9.2], [7.95, 9.61], [7.67, 9.89], [7.4, 10.03], [6.71, 10.03], [6.43, 9.89], [6.02, 9.47], [4.91, 6.43], [3.94, 3.25]]
        }
        onClicked: run("clipboard")
    }
}
