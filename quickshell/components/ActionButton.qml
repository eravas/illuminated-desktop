import QtQuick
import QtQuick.Controls
import "../theme"
import "../config"
import "../materials"
// A printed control on vellum: Alegreya in ink over a hairline rule. Hover deepens the rule and
// lays a faint wash; pressed or checked fills with the active paper; keyboard focus is the
// dithered focus light (FocusHalo), never a coloured box.
Button {
    id: root
    property alias horizontalAlignment: label.horizontalAlignment
    property bool ruled: true
    implicitHeight: Settings.controlHeight
    implicitWidth: Math.max(36, label.implicitWidth + 20)
    focusPolicy: Qt.StrongFocus
    activeFocusOnTab: true
    Keys.onReturnPressed: function(event) { if (root.enabled && !event.isAutoRepeat) root.clicked(); }
    Keys.onEnterPressed: function(event) { if (root.enabled && !event.isAutoRepeat) root.clicked(); }
    contentItem: Text {
        id: label
        text: root.text
        textFormat: Text.PlainText
        font.family: Theme.serifFamily
        font.pixelSize: Settings.fontPixelSize
        color: root.enabled ? Theme.ink : Theme.disabledInk
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    background: Item {
        Rectangle {
            anchors.fill: parent
            radius: Theme.radius
            color: root.down || root.checked ? Theme.activePaper : Theme.hoverPaper
            opacity: root.down || root.checked ? 0.9 : root.hovered && root.enabled ? 0.55 : 0
        }
        Rectangle {
            visible: root.ruled
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 6; rightMargin: 6; bottomMargin: 3 }
            height: root.checked || root.hovered ? 2 : 1
            color: Theme.ink
            opacity: !root.enabled ? 0.15 : root.checked ? 0.85 : root.hovered ? 0.6 : 0.28
        }
        Loader { anchors.fill: parent; active: root.visualFocus; sourceComponent: FocusHalo { radius: Theme.radius } }
    }
}
