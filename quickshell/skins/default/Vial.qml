import QtQuick
import qs.skin
// The ink vial: the volume as an ink level. Click deals Levels; scroll changes the volume by
// 5 %; middle-click mutes.
SkinItem {
    size: [17, 9]; anchor: [16, 4.5]
    hand: "levels"
    tag: Actions.label("deal:levels")
    onClicked: button => run(button === Qt.MiddleButton ? "mute" : "deal:levels")
    onWheelStep: direction => run(direction > 0 ? "volume:+5" : "volume:-5")
    InkFill { file: Qt.resolvedUrl("elements/vial.png"); level: ShellState.volume }
}
