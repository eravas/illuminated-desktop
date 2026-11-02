import QtQuick
import "../config"
QtObject {
    id: root
    required property var shellScreen
    readonly property var state: DesktopState.context(shellScreen ? shellScreen.name : "", false)
    readonly property bool ready: state.ready
    readonly property string modelKind: state.modelKind
    readonly property string monitorName: state.monitorName
    readonly property bool monitorFocused: state.monitorFocused
    readonly property var spaces: state.spaces
    readonly property var selection: state.selection
    function activateWorkspace(space, extend) { DesktopState.activate(space, !!extend); }
}
