import QtQuick
import qs.skin
// The pen nib: opens the launcher. A polygon hit area (the nib's outline, grown a little).
SkinItem {
    size: [17, 10]; anchor: [16, 5]
    tag: "Launcher"
    hitShape: HitPolygon {
        pad: 1
        points: [[0.07, 0.48], [3.66, 0.48], [4.22, 0.62], [8.78, 1.87], [15.56, 4.63], [15.69, 4.77], [15.69, 5.19], [15.42, 5.46], [8.78, 8.23], [3.94, 9.47], [0.07, 9.47]]
    }
    onClicked: run("launcher")
    FrameImage { file: Qt.resolvedUrl("elements/nib.png") }
}
