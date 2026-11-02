import QtQuick
import "../materials"
import "../config"
// One rail slot: an illuminated initial with a hover tag. Clickable only inside the strip.
Item {
    id: root
    property alias mark: initial.mark
    property string label: ""
    property var tag: null
    signal activated()
    implicitWidth: 64
    implicitHeight: Math.max(40, Settings.targetSize)
    Accessible.role: Accessible.Button
    Accessible.name: label
    Initial { id: initial; anchors.centerIn: parent }
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: if (root.tag) root.tag.show(root, root.label, "right")
        onExited: if (root.tag) root.tag.hide()
        onClicked: root.activated()
    }
}
