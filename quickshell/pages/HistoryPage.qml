pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../components"
import "../theme"
import "../services"
ColumnLayout {
    spacing: Theme.gap
    Component.onCompleted: NotificationHub.markRead()
    InkLabel { text: "Correspondence"; variant: "heading" }
    RowLayout {
        ActionButton { text: NotificationHub.dnd ? "Disable Do Not Disturb" : "Do Not Disturb"; onClicked: NotificationHub.dnd = !NotificationHub.dnd }
        ActionButton { text: "Clear history"; onClicked: NotificationHub.clear() }
    }
    InkLabel { text: NotificationHub.enabled ? NotificationHub.history.length + " retained notifications" : "Notification daemon disabled. Enable explicitly after stopping your previous daemon."; Layout.fillWidth: true }
    InkLabel { text: NotificationHub.storageError; visible: text !== ""; Layout.fillWidth: true }
    Repeater {
        model: NotificationHub.history
        ColumnLayout {
            id: row
            required property var modelData
            Layout.fillWidth: true
            InkLabel { text: row.modelData.app + " · " + new Date(row.modelData.timestamp).toLocaleString(); color: Theme.mutedInk; Layout.fillWidth: true }
            InkLabel { text: row.modelData.summary; font.bold: true; Layout.fillWidth: true }
            InkLabel { text: row.modelData.body; Layout.fillWidth: true }
            RowLayout {
                Repeater {
                    model: NotificationHub.live[row.modelData.id] ? NotificationHub.live[row.modelData.id].actions : []
                    ActionButton { required property var modelData; required property int index; text: modelData.text; onClicked: NotificationHub.invoke(row.modelData.id, index) }
                }
                ActionButton { text: "Dismiss"; onClicked: { if (row.modelData.active) NotificationHub.dismiss(row.modelData.id); else NotificationHub.removeHistory(row.modelData.uid); } }
            }
        }
    }
}
