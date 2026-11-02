pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "../theme"
import "../config"
import "../materials"
// Workspaces as period numerals (minuscule Roman with the terminal j by default), with the
// brass loupe over the active one. Scrolls when the rail runs short (a mounted device's
// footprint takes space); names show on hover. DESIGN.md §6.
Item {
    id: root
    required property var context
    property alias workspaceItems: workspaceItems
    property var tag: null
    readonly property int rowHeight: Math.round(30 * Theme.typeScale)
    implicitHeight: list.contentHeight
    readonly property int activeIndex: (context.spaces || []).findIndex(w => w.active)
    Flickable {
        id: list
        anchors.fill: parent
        contentHeight: column.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height
        Column {
            id: column
            width: list.width
            Repeater {
                id: workspaceItems
                model: ScriptModel {
                    values: root.context.spaces
                    objectProp: "id"
                    comparisonMode: ObjectComparison.Identity
                }
                Item {
                    id: slot
                    required property var modelData
                    required property int index
                    readonly property var space: (root.context.spaces || []).find(w => w.id === modelData.id) || ({})
                    readonly property bool occupied: space.count !== undefined ? space.count > 0 : space.toplevels ? space.toplevels.values.length > 0 : false
                    readonly property string text: Theme.numeral(space.id) || String(space.name).slice(0, 3)
                    readonly property string named: space.name && String(space.name) !== String(space.id) ? String(space.name) : ""
                    width: column.width; height: root.rowHeight
                    Accessible.role: Accessible.Button
                    Accessible.name: "Workspace " + space.id + (named ? ", " + named : "") + (space.active ? ", active" : "")
                    Text {
                        anchors.centerIn: parent
                        visible: !slot.space.active
                        text: slot.text; textFormat: Text.PlainText
                        font.family: Theme.cardFamily; font.bold: Theme.cardBold; font.pixelSize: Math.round(20 * Theme.typeScale)
                        color: slot.space.urgent ? Theme.urgent : slot.occupied ? Theme.mutedInk : Theme.disabledInk
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: if (root.tag) root.tag.show(slot, slot.named || ("Workspace " + slot.text), "right")
                        onExited: if (root.tag) root.tag.hide()
                        onClicked: function(mouse) { root.context.activateWorkspace(slot.space, !!(mouse.modifiers & (Qt.ControlModifier | Qt.ShiftModifier))); }
                    }
                }
            }
        }
        // The loupe rides with the active numeral and may overlap its neighbours.
        Item {
            id: lens
            visible: root.activeIndex >= 0
            width: 54; height: 54
            x: (column.width - width) / 2
            y: root.activeIndex * root.rowHeight + root.rowHeight / 2 - height / 2
            Behavior on y { enabled: Settings.reading.loupeMotion === "slide" && Settings.reading.transitions === "full"; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            readonly property string text: root.activeIndex >= 0 ? Theme.numeral(root.context.spaces[root.activeIndex].id) || String(root.context.spaces[root.activeIndex].name).slice(0, 3) : ""
            TextMetrics { id: plain; font.family: Theme.cardFamily; font.pixelSize: Math.round(20 * Theme.typeScale); text: lens.text }
            // Magnified up to 1.26×, less where a wide numeral would not fit the glass.
            readonly property real magnification: Settings.reading.loupe === "ring" ? 1 : Math.min(1.26, (54 - 2 * 6 - 6) / Math.max(1, plain.advanceWidth))
            Loupe {
                which: "rail"
                anchors.horizontalCenter: parent.horizontalCenter
                Text {
                    anchors.centerIn: parent
                    text: lens.text; textFormat: Text.PlainText
                    font.family: Theme.cardFamily; font.bold: Theme.cardBold
                    font.pixelSize: Math.round(20 * Theme.typeScale * lens.magnification)
                    color: Theme.ink
                }
            }
        }
    }
    onActiveIndexChanged: if (activeIndex >= 0) {
        const y = activeIndex * rowHeight;
        if (y < list.contentY) list.contentY = y; else if (y + rowHeight > list.contentY + list.height) list.contentY = y + rowHeight - list.height;
    }
}
