import QtQuick
import qs.skin
// The printed tray mark above the launcher: opens the tray sheet.
SkinItem {
    units: "px"; size: [24, 24]; anchor: [12, 12]; place: "center"
    shadowMargin: 0
    tag: "Tray"
    hitShape: HitRect { rect: [-8, -4, 40, 32] }
    onClicked: run("tray")
    FrameImage { file: Qt.resolvedUrl("elements/tray.png"); count: 2; frame: ShellState.mode === "dark" ? 1 : 0 }
}
