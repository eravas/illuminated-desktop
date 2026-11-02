import QtQuick
import Quickshell
import "../theme"
import "../config"
import "../materials"
// One window in the dock: a large app icon with its workspace numeral underneath (none when
// minimised, icon faded). Focused: a brass loupe centred on the icon, magnifying it.
// DESIGN-SYSTEM.md §3.13.
Item {
    id: root
    required property var client
    property bool pending: false
    property var tag: null
    signal chosen(bool shift)
    readonly property var entry: {
        const id = client.appId;
        if (!id) return null;
        return (DesktopEntries.heuristicLookup ? DesktopEntries.heuristicLookup(id) : null) || DesktopEntries.byId(id) || null;
    }
    readonly property string iconSource: {
        const name = entry && entry.icon ? entry.icon : client.appId;
        return name ? Quickshell.iconPath(name, true) : "";
    }
    readonly property string title: client.title || (entry ? entry.name : client.appId) || "Window"
    implicitWidth: Math.max(42, Settings.targetSize)
    implicitHeight: 46
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: title + (client.minimized ? " (minimised)" : ", workspace " + client.workspaceName)
    Keys.onReturnPressed: function(event) { root.chosen(!!(event.modifiers & Qt.ShiftModifier)); }
    onActiveFocusChanged: if (activeFocus && tag && Settings.reading.hoverInfo !== "hover") tag.show(root, root.title, "below")
    // Inline components cannot see this file's ids, so the icon takes what it shows.
    component Icon: Item {
        id: icon
        property real size: 30
        property string source: ""
        property string letter: "?"
        width: size; height: size
        Image {
            id: image
            anchors.fill: parent
            visible: status === Image.Ready
            source: icon.source
            sourceSize.width: 64; sourceSize.height: 64      // decoded once at a small size
            asynchronous: true
            fillMode: Image.PreserveAspectFit
        }
        Rectangle {   // no icon: the app's initial on a sunken tile
            anchors.fill: parent
            visible: image.status !== Image.Ready
            radius: 7 * icon.size / 30
            color: Theme.sunken; border.color: Theme.edge; border.width: 1
            Text { anchors.centerIn: parent; text: icon.letter; font.family: Theme.serifFamily; font.bold: true; font.pixelSize: 14 * icon.size / 30; color: Theme.mutedInk }
        }
    }
    readonly property string letter: (client.appId || title || "?").charAt(0).toUpperCase()
    Column {
        id: lead
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.client.minimized ? 1 : 1
        spacing: 1
        Item {
            id: iconWrap
            width: 30; height: 30
            anchors.horizontalCenter: parent.horizontalCenter
            Icon { source: root.iconSource; letter: root.letter; visible: !root.client.focused; opacity: root.client.minimized ? 0.45 : 1 }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: !root.client.minimized
            height: 13
            text: Theme.numeral(root.client.workspace) || root.client.workspaceName
            textFormat: Text.PlainText
            font.family: Theme.cardFamily; font.bold: Theme.cardBold; font.pixelSize: Math.round(13 * Theme.typeScale)
            color: Theme.ink
            verticalAlignment: Text.AlignVCenter
        }
    }
    // Focus: loupe centred on the icon; diameter 1.12 × icon box + 18 px. The brass may cross
    // the vellum edge; only the glass must stay inside it.
    Item {
        visible: root.client.focused
        readonly property real diameter: Math.round(30 * 1.12 + 18)
        width: diameter; height: diameter
        x: lead.x + iconWrap.x + 15 - diameter / 2
        y: lead.y + iconWrap.y + 15 - diameter / 2
        Loupe {
            which: "dock"
            Icon { anchors.centerIn: parent; source: root.iconSource; letter: root.letter; size: Settings.reading.loupe === "ring" ? 30 : Math.round(30 * 1.12) }
        }
    }
    Rectangle {   // pending Shift selection: a hatched mark under the entry
        visible: root.pending
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 6; rightMargin: 6; bottomMargin: -6 }
        height: 3
        color: Theme.focusCore
    }
    Rectangle {   // keyboard focus ring (always visible under the Accessibility preset)
        visible: root.activeFocus
        anchors.fill: parent; anchors.margins: -2
        color: "transparent"; border.color: Theme.focusCore; border.width: Settings.reading.focus === "solid" ? 3 : 2
        radius: 9
    }
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onEntered: if (root.tag) root.tag.show(root, root.title, "below")
        onExited: if (root.tag && !root.activeFocus) root.tag.hide()
        onClicked: function(mouse) { root.chosen(!!(mouse.modifiers & Qt.ShiftModifier) || mouse.button === Qt.MiddleButton); }
    }
}
