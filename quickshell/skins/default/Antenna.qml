import QtQuick
import qs.skin
// The antenna: signal stage 0–4 (or connecting), in the mode's ink. Click deals Connections.
SkinItem {
    size: [17, 12]; anchor: [16, 6]
    hand: "connections"
    tag: Actions.label("deal:connections")
    onClicked: run("deal:connections")
    FrameImage {
        file: Qt.resolvedUrl("elements/antenna.png"); count: 12
        frame: (ShellState.mode === "dark" ? 6 : 0) + (ShellState.networkConnecting && ShellState.networkStage === 0 ? 5 : ShellState.networkStage)
    }
}
