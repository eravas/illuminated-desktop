pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import "services"
import "skin"
import "artifacts"
import "components"
import "theme"
import "config"
import "compositors"
Scope {
    id: root
    Component.onCompleted: NotificationHub.enabled = true
    Component.onDestruction: NotificationHub.enabled = false
    NotificationServer {
        id: server
        keepOnReload: true
        bodySupported: true
        bodyMarkupSupported: false
        actionsSupported: true
        persistenceSupported: true
        onNotification: function(notification) { notification.tracked = true; NotificationHub.receive(notification); }
    }
    Variants {
        model: server.trackedNotifications.values
        Scope {
            id: watcher
            required property var modelData
            Component.onCompleted: if (!NotificationHub.live[modelData.id]) NotificationHub.receive(modelData, true)
            Connections {
                target: watcher.modelData
                function onClosed() { NotificationHub.closed(watcher.modelData.id); }
                function onSummaryChanged() { NotificationHub.receive(watcher.modelData); }
                function onBodyChanged() { NotificationHub.receive(watcher.modelData); }
                function onExpireTimeoutChanged() { if (watcher.modelData.expireTimeout === 0) expiry.stop(); else expiry.restart(); }
            }
            Timer { id: expiry; interval: watcher.modelData.expireTimeout > 0 ? watcher.modelData.expireTimeout : 6000; running: watcher.modelData.expireTimeout !== 0 && watcher.modelData.urgency !== NotificationUrgency.Critical; onTriggered: watcher.modelData.expire() }
        }
    }
    // Slips (SURFACES.md, notifications): cardstock slips sliding out from behind the rail's edge
    // near its foot, newest lowest, stacking upward. Urgency is an edge band plus a word, never
    // colour alone. Without the rail they slide in from the right edge, top down.
    PanelWindow {
        id: popup
        readonly property bool fromRail: Settings.enableRail
        screen: DesktopState.focusedScreen
        anchors { top: true; bottom: true; left: popup.fromRail; right: !popup.fromRail }
        margins { left: popup.fromRail ? Settings.railInset + Settings.railWidth : 0; right: popup.fromRail ? 0 : 8 }
        implicitWidth: Math.min(360, screen ? screen.width / 3 : 360) + 16
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "illuminated-notifications"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        color: "transparent"
        visible: NotificationHub.popups.length > 0
        mask: Region { item: stack }
        Column {
            id: stack
            width: popup.width - 16
            x: popup.fromRail ? 6 : 8
            y: popup.fromRail ? popup.height - height - Math.round(popup.height * 0.12) : 12
            spacing: 8
            // Newest nearest the rail's foot: reverse order when stacking upward. ScriptModel keeps
            // delegates (and their slide) across the hub's twice-a-second refresh: rows that did not change are the same objects (3).
            Repeater {
                model: ScriptModel { values: popup.fromRail ? NotificationHub.popups.slice().reverse() : NotificationHub.popups }
                Slip {
                    required property var modelData
                    row: modelData
                    width: stack.width
                    fromRail: popup.fromRail
                    onOpenHistory: Actions.run("history", {screen: popup.screen})
                }
            }
        }
    }
    component Slip: Item {
        id: slip
        property var row: ({})
        property bool fromRail: true
        signal openHistory()
        readonly property bool critical: row.urgency === 2
        readonly property var actions: { const n = NotificationHub.live[row.id]; return n ? n.actions : []; }
        height: card.height
        clip: true                       // the rail edge is where the slip comes out from
        property real out: 0
        Component.onCompleted: out = 1
        Behavior on out { NumberAnimation { duration: Theme.motionDuration > 0 ? 220 : 0; easing.type: Easing.OutCubic } }
        Item {
            id: card
            x: (slip.fromRail ? -1 : 1) * (1 - slip.out) * (slip.width + 12)
            width: slip.width - 6; height: content.implicitHeight + 24
            Rectangle { x: 3; y: 4; width: parent.width; height: parent.height; radius: 3; color: "#000000"; opacity: 0.22 }   // baked drop shadow
            Rectangle { anchors.fill: parent; radius: 3; color: Theme.cardstock; border.color: Theme.edge; border.width: 1 }
            // Urgency: a band on the edge the slip came from, and a word.
            Rectangle {
                visible: slip.row.urgency !== 0
                x: slip.fromRail ? 0 : parent.width - width; width: slip.critical ? 6 : 3; height: parent.height
                color: slip.critical ? Theme.urgent : Theme.accent
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: slip.openHistory() }
            ColumnLayout {
                id: content
                x: 16; y: 12; width: parent.width - 28
                spacing: 2
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        Layout.fillWidth: true
                        text: slip.row.app || "Notice"; textFormat: Text.PlainText; elide: Text.ElideRight
                        font.family: Theme.cardFamily; font.bold: Theme.cardBold; font.pixelSize: Math.round(17 * Theme.typeScale)
                        color: Theme.ink
                    }
                    InkLabel { visible: slip.critical; text: "Urgent"; variant: "small"; color: Theme.urgent; font.letterSpacing: 1; font.capitalization: Font.AllUppercase }
                    ActionButton { text: "×"; ruled: false; implicitWidth: 28; Accessible.name: "Dismiss"; onClicked: NotificationHub.dismiss(slip.row.id) }
                }
                InkLabel { text: slip.row.summary || ""; maximumLineCount: 3; elide: Text.ElideRight; font.bold: true; Layout.fillWidth: true; visible: text !== "" }
                InkLabel { text: slip.row.body || ""; maximumLineCount: 4; elide: Text.ElideRight; Layout.fillWidth: true; visible: text !== "" }
                Flow {
                    Layout.fillWidth: true; Layout.topMargin: 4; spacing: 6
                    visible: slip.actions.length > 0
                    Repeater {
                        model: slip.actions
                        ActionButton { required property var modelData; required property int index; text: modelData.text; onClicked: NotificationHub.invoke(slip.row.id, index) }
                    }
                }
            }
        }
    }
}
