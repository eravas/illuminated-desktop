import QtQuick
import qs.skin
// The fountain-pen converter: the battery as an ink level; canary bands while charging, a canary
// dot while held on AC. Shown only on a machine with a battery. Click deals Battery.
SkinItem {
    size: [17, 28]; anchor: [16, 14]
    hand: "battery"
    shown: ShellState.batteryPresent
    tag: Actions.label("deal:battery")
    onClicked: run("deal:battery")
    InkFill {
        file: Qt.resolvedUrl("elements/converter.png"); variants: 3
        variant: ShellState.batteryState === "chg" ? 1 : ShellState.batteryState === "held" ? 2 : 0
        level: ShellState.batteryLevel
    }
}
