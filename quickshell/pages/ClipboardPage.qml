pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../components"
import "../theme"
import "../services"
import "../artifacts"
// Clipboard history (rail glyph). Choosing an entry puts it back on the clipboard.
ColumnLayout {
    spacing: Theme.gap
    Component.onCompleted: ClipboardHistory.refresh()
    InkLabel { text: "Clipboard"; variant: "heading" }
    InkLabel { visible: ClipboardHistory.error !== ""; text: ClipboardHistory.error; color: Theme.urgent; Layout.fillWidth: true }
    InkLabel { visible: !ClipboardHistory.loading && ClipboardHistory.entries.length === 0 && ClipboardHistory.error === ""; text: "Nothing copied yet. History needs `wl-paste --watch cliphist store` running in your session."; Layout.fillWidth: true }
    Repeater {
        model: ClipboardHistory.entries
        RowLayout {
            id: row
            required property var modelData
            Layout.fillWidth: true
            ActionButton {
                Layout.fillWidth: true
                text: row.modelData.preview.replace(/\s+/g, " ")
                horizontalAlignment: Text.AlignLeft
                onClicked: { ClipboardHistory.choose(row.modelData); if (!row.modelData.binary) Navigation.dismiss(); }
            }
            ActionButton { text: "✕"; Accessible.name: "Delete"; onClicked: ClipboardHistory.remove(row.modelData) }
        }
    }
}
