import QtQuick
import QtQuick.Controls
import "../theme"
import "../config"
import "../materials"
// A field written on a rule: no box, ink on the vellum, the baseline darkening with focus, and
// the focus light around it while focused from the keyboard or typing.
TextField {
    id: root
    property bool lettered: false        // blackletter placeholder (the launcher's Search)
    implicitHeight: Settings.option("dimensions.controlHeight")
    font.family: Theme.serifFamily
    font.pixelSize: Settings.fontPixelSize
    color: Theme.ink
    selectionColor: Theme.accent
    selectedTextColor: Theme.paper
    leftPadding: 6; rightPadding: 6; topPadding: 6; bottomPadding: 8
    background: Item {
        Text {
            visible: root.lettered && !root.text && !root.preeditText
            anchors { left: parent.left; leftMargin: root.leftPadding; verticalCenter: parent.verticalCenter }
            text: root.placeholderText
            font.family: Theme.cardFamily; font.bold: Theme.cardBold; font.pixelSize: Math.round(root.font.pixelSize * 1.35)
            color: Theme.mutedInk
        }
        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; bottomMargin: 3 }
            height: root.activeFocus ? 2 : 1
            color: Theme.ink
            opacity: root.activeFocus ? 0.8 : 0.35
        }
        Loader { anchors.fill: parent; active: root.activeFocus; sourceComponent: FocusHalo { radius: Theme.radius } }
    }
    // The lettered placeholder replaces Qt's own.
    placeholderTextColor: lettered ? "transparent" : Theme.mutedInk
}
