import QtQuick
import qs.skin
// The default paper with the tray mark stamped on it, and a paperclip that wiggles when the
// pointer reaches it.
SkinItem {
    id: paper
    size: [18, 22]; anchor: [0, 22]
    tag: Actions.label("notifications")
    onClicked: run("notifications")
    FrameImage { file: Qt.resolvedUrl("elements/paper.png"); count: 7; frame: Math.min(6, ShellState.unread) }
    SkinItem {                                   // the stamp opens the tray
        objectName: "tray"
        x: 8 * paper.unit; y: 15 * paper.unit; size: [6, 6]
        tag: "Tray"
        hitShape: HitRect { rect: [-1.7, -1.7, 9.4, 9.4] }
        onClicked: run("tray")
    }
    SkinItem {                                   // the paperclip
        id: paperclip
        objectName: "paperclip"
        visible: Actions.available("clipboard")
        x: -1.31 * paper.unit; y: 5.53 * paper.unit; size: [12, 12]; anchor: [0, 0]
        tag: "Clipboard · " + ShellState.clipboardCount + (ShellState.clipboardCount === 1 ? " entry" : " entries")
        onClicked: run("clipboard")
        property int frame: 0
        onHoveredChanged: if (hovered) wiggle.restart()
        NumberAnimation { id: wiggle; target: paperclip; property: "frame"; from: 0; to: 4; duration: 5 * 1000 / 16 }
        FrameImage { file: Qt.resolvedUrl("elements/clip.png"); count: 5; frame: paperclip.frame }
    }
}
