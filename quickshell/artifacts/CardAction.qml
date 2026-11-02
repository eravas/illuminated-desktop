import QtQuick
// A clickable line of blackletter on a card back (Mixer, See All ›, Sleep…).
// `text` is what the runtime tests look for.
Item {
    id: root
    property string text
    property color ink
    property var wash: null
    property real faceWidth
    property real faceHeight
    property real originX: 0
    property real originY: 0
    property string family
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
        text: root.text; ink: root.ink; wash: root.wash
        faceWidth: root.faceWidth; faceHeight: root.faceHeight
        originX: root.originX; originY: root.originY
        family: root.family; pixelSize: root.pixelSize; horizontalAlignment: root.horizontalAlignment
    }
    Rectangle {   // keyboard focus: a hairline under the words, in the text's own ink
        visible: root.activeFocus
        y: parent.height - 2; height: 1.5
        width: Math.min(parent.width, label.implicitWidth)
        x: root.horizontalAlignment === Text.AlignHCenter ? (parent.width - width) / 2 : root.horizontalAlignment === Text.AlignRight ? parent.width - width : 0
        color: root.ink
    }
    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.triggered() }
}
