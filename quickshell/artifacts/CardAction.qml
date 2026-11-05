import QtQuick
// A clickable line of blackletter on a card back (Mixer, See All ›, Sleep…).
// `text` is what the runtime tests look for.
Item {
    id: root
    property string text
    property var face: null           // as SplitText: {item, ink, wash}
    property real pixelSize: 18
    property int horizontalAlignment: Text.AlignLeft
    property bool tabStop: true
    signal triggered()
    activeFocusOnTab: tabStop
    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight + 4
    Accessible.role: Accessible.Button
    Accessible.name: text
    Accessible.onPressAction: triggered()
    Keys.onReturnPressed: function(event) { if (!event.isAutoRepeat) root.triggered(); }
    Keys.onEnterPressed: function(event) { if (!event.isAutoRepeat) root.triggered(); }
    Keys.onSpacePressed: function(event) { if (!event.isAutoRepeat) root.triggered(); }
    SplitText {
        id: label
        anchors.fill: parent
        text: root.text; face: root.face
        pixelSize: root.pixelSize; horizontalAlignment: root.horizontalAlignment
    }
    Rectangle {   // keyboard focus: a hairline under the words, in the text's own ink
        visible: root.activeFocus
        y: parent.height - 2; height: 1.5
        width: Math.min(parent.width, label.implicitWidth)
        x: root.horizontalAlignment === Text.AlignHCenter ? (parent.width - width) / 2 : root.horizontalAlignment === Text.AlignRight ? parent.width - width : 0
        color: label.ink
    }
    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.triggered() }
}
