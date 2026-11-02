import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../theme"
import "../config"
import "../artifacts"
import "../components"
import "../materials"
import "../compositors"
// The prompt sheet (SURFACES.md, prompts): a centred, solid-edged vellum sheet that unfurls flat
// from the top, over a light scrim, with the keyboard held exclusively while it is up.
// Blackletter title, Alegreya body, a field on a rule with the focus light, Cancel and the
// action. Escape cancels. Shows Prompts.current; nothing else.
PanelWindow {
    id: root
    readonly property QtObject request: Prompts.current
    property var output: null
    onRequestChanged: {
        if (request) { output = DesktopState.focusedScreen; field.text = ""; }
    }
    screen: output
    visible: request !== null || sheet.progress > 0
    anchors { left: true; right: true; top: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "illuminated-prompt"
    WlrLayershell.keyboardFocus: request ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    function submit() {
        if (!request || !request.responseRequired) return;
        const answer = field.text;
        field.text = "";   // never kept on screen or in the field after it is sent
        request.submitted(answer);
    }
    function cancel() { if (request) request.cancelled(); }

    Rectangle { anchors.fill: parent; color: Theme.ink; opacity: 0.18 * sheet.progress }
    MouseArea { anchors.fill: parent }   // modal: clicks outside the sheet do nothing

    VellumSheet {
        id: sheet
        width: Math.min(440, root.width - 48)
        height: Math.min(column.implicitHeight + 2 * padding, root.height - 48)
        x: Math.round((root.width - width) / 2); y: Math.round((root.height - height) * 0.38)
        offX: x; offY: y
        opened: root.request !== null
        padding: 26
        solid: true
    }
    // The sheet's content sits outside the Loader so it can size the sheet.
    ColumnLayout {
        id: column
        x: sheet.x + sheet.padding; y: sheet.y + sheet.padding
        width: sheet.width - 2 * sheet.padding
        spacing: 10
        opacity: sheet.progress > 0.85 ? 1 : 0
        visible: root.request !== null
        InkLabel { text: root.request ? root.request.title : ""; variant: "heading"; Layout.fillWidth: true }
        InkLabel { text: root.request ? root.request.message : ""; Layout.fillWidth: true; visible: text !== "" }
        // A choice of identity (polkit: which administrator), only when there is one to make.
        Flow {
            Layout.fillWidth: true; spacing: 6
            visible: root.request !== null && root.request.identities.length > 1
            Repeater {
                model: root.request ? root.request.identities : []
                ActionButton {
                    required property string modelData
                    required property int index
                    text: modelData; checkable: false
                    checked: root.request !== null && root.request.identity === index
                    onClicked: if (root.request) root.request.identityChosen(index)
                }
            }
        }
        SearchField {
            id: field
            Layout.fillWidth: true
            placeholderText: root.request ? root.request.prompt : ""
            echoMode: root.request && !root.request.secret ? TextInput.Normal : TextInput.Password
            enabled: root.request !== null && root.request.responseRequired
            focus: true
            inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
            onAccepted: root.submit()
            Keys.onEscapePressed: root.cancel()
            onEnabledChanged: if (enabled) forceActiveFocus()
        }
        InkLabel {
            Layout.fillWidth: true
            visible: text !== ""
            text: root.request ? (root.request.error || root.request.note) : ""
            color: root.request && root.request.error ? Theme.urgent : Theme.mutedInk
            variant: "small"
        }
        RowLayout {
            Layout.fillWidth: true; Layout.topMargin: 4
            Item { Layout.fillWidth: true }
            ActionButton { text: "Cancel"; onClicked: root.cancel() }
            ActionButton {
                text: root.request ? root.request.actionLabel : ""
                enabled: root.request !== null && root.request.responseRequired && field.text.length > 0
                onClicked: root.submit()
            }
        }
    }
    Shortcut { sequence: "Escape"; enabled: root.request !== null; onActivated: root.cancel() }
    onVisibleChanged: if (visible) field.forceActiveFocus()
}
