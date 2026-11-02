pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import "../components"
import "../artifacts"
import "../theme"
// The tray sheet. From the rail's tray glyph it lists every item; choosing one activates
// it, or opens its menu here (items that only have a menu, or by its ⋯ button).
ColumnLayout {
    id: root
    property var stack: []
    readonly property var item: Navigation.trayItem
    QsMenuOpener { id: opener; menu: root.stack.length ? root.stack[root.stack.length - 1] : root.item ? root.item.menu : null }
    InkLabel { text: root.item ? root.item.title || root.item.id : "Tray"; variant: "heading"; Layout.fillWidth: true }
    ActionButton { text: "‹ Back"; visible: root.stack.length > 0 || root.item !== null; onClicked: { if (root.stack.length) root.stack = root.stack.slice(0, -1); else Navigation.trayItem = null; } }
    InkLabel { visible: !root.item && SystemTray.items.values.length === 0; text: "No tray items."; Layout.fillWidth: true }
    Repeater {
        model: root.item ? [] : SystemTray.items.values
        RowLayout {
            id: entry
            required property var modelData
            Layout.fillWidth: true
            ActionButton {
                Layout.fillWidth: true
                text: entry.modelData.title || entry.modelData.tooltipTitle || entry.modelData.id
                icon.source: entry.modelData.icon
                onClicked: { if (entry.modelData.onlyMenu && entry.modelData.hasMenu) Navigation.trayItem = entry.modelData; else { entry.modelData.activate(); Navigation.dismiss(); } }
            }
            ActionButton { visible: entry.modelData.hasMenu; text: "⋯"; Accessible.name: "Menu"; onClicked: Navigation.trayItem = entry.modelData }
        }
    }
    Repeater {
        model: root.item ? opener.children : []
        ActionButton {
            required property var modelData
            Layout.fillWidth: true
            text: modelData.isSeparator ? "────────" : (modelData.checkState ? "✓ " : "") + modelData.text + (modelData.hasChildren ? " ›" : "")
            enabled: modelData.enabled && !modelData.isSeparator
            onClicked: { if (modelData.hasChildren) root.stack = root.stack.concat([modelData]); else { modelData.triggered(); Navigation.dismiss(); } }
        }
    }
}
