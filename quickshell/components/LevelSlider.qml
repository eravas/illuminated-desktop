import QtQuick
import QtQuick.Controls
import "../theme"
import "../materials"
// A level on vellum: a hairline rule, the level as a solid accent stroke up to an ink mark
// (the level-mark rule of the cards, without the dither, at control size). Focus is the halo
// around the mark.
Slider {
    id: root
    implicitHeight: 28
    background: Item {
        x: root.leftPadding; y: root.topPadding + root.availableHeight / 2 - height / 2
        width: root.availableWidth; height: 6
        Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 1; color: Theme.ink; opacity: 0.3 }
        Rectangle { anchors.verticalCenter: parent.verticalCenter; width: root.visualPosition * parent.width; height: 4; radius: 1; color: Theme.accent }
    }
    handle: Item {
        x: root.leftPadding + root.visualPosition * (root.availableWidth - width)
        y: root.topPadding + root.availableHeight / 2 - height / 2
        width: 4; height: 18
        Rectangle { anchors.fill: parent; radius: 1; color: Theme.ink }
        Loader { anchors.fill: parent; active: root.visualFocus; sourceComponent: FocusHalo { radius: 1 } }
    }
    opacity: enabled ? 1 : .45
}
