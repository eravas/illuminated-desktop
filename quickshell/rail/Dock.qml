pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../theme"
import "../config"
import "../compositors"
import "../materials"
import "../skin"
import "../materials/DeviceGeometry.js" as Geo
// The top dock (DESIGN.md §6): every window in opening order, scrolling when it overflows.
// Click: a visible window switches to its workspace; a minimised one comes here. Shift-click
// (or middle-click) selects windows to bring here, applied in click order when Shift is
// released. Permanent (space held by a Reservation) or auto-hide: a ~300 ms dwell in the
// top-right eighth of the top edge reveals it; it hides after the pointer leaves, but not
// during a Shift selection. It takes keyboard focus while hovered so it can see Shift.
// The skin may add its own elements before and after the windows (docs/SKINS.md, "dock").
PanelWindow {
    id: root
    anchors { top: true; left: true; right: true }
    margins.left: Settings.enableRail ? Settings.railReserved + 3 : 8
    margins.right: 8
    implicitHeight: 8 + Settings.railWidth + 8
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "illuminated-dock"
    WlrLayershell.keyboardFocus: hovered ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    readonly property string mode: Settings.dockMode(screen ? screen.name : "", screen ? screen.height : 0)
    readonly property bool autoHide: mode === "autohide"
    property bool revealed: !autoHide
    readonly property bool hovered: stripHover.hovered || triggerHover.hovered
    property var pending: []                    // window ids, in click order
    readonly property var windows: DesktopState.windows
    readonly property real pxmm: Geo.pxPerMm(Settings.mediaScale, screen ? screen.physicalPixelDensity : 0, screen ? screen.devicePixelRatio : 1)
    readonly property var chrome: SkinStore.manifest.dock || ({})
    onAutoHideChanged: revealed = !autoHide
    // When hidden only the trigger zone takes input: the top-right eighth, 4 px deep.
    mask: Region { item: root.revealed ? strip : trigger }

    Tag { id: hoverTag; host: root }
    Item {
        id: trigger
        x: root.width * 7 / 8; y: 0; width: root.width / 8; height: 4
        HoverHandler { id: triggerHover }
    }
    Timer { id: dwell; interval: Settings.dockDwell; running: root.autoHide && !root.revealed && triggerHover.hovered; onTriggered: root.revealed = true }
    Timer { id: hideTimer; interval: Settings.dockHideDelay; running: root.autoHide && root.revealed && !root.hovered && root.pending.length === 0; onTriggered: { root.revealed = false; hoverTag.hide(); } }
    function apply() {
        const chosen = root.pending.map(id => root.windows.find(w => w.id === id)).filter(w => w);
        root.pending = [];
        chosen.forEach(w => DesktopState.bringWindow(w));
        if (chosen.length) DesktopState.focusWindow(chosen[chosen.length - 1]);
    }
    function choose(w, shift) {
        if (shift && DesktopState.capabilities.moveWindow) {
            const i = pending.indexOf(w.id);
            pending = i < 0 ? pending.concat([w.id]) : pending.filter(id => id !== w.id);
            return;
        }
        DesktopState.focusWindow(w);
    }
    Vellum {
        id: strip
        x: 0; width: root.width; height: Settings.railWidth
        y: root.revealed ? 8 : -height - 12
        Behavior on y { enabled: Settings.reading.transitions === "full"; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        visible: y > -height - 10
        offX: root.margins.left; offY: 8
        horizontal: true
        HoverHandler { id: stripHover }
        FocusScope {
            anchors.fill: parent
            focus: true
            Keys.onReleased: function(event) { if (event.key === Qt.Key_Shift && root.pending.length) root.apply(); }
            Chrome { id: before; items: root.chrome.before || []; pxmm: root.pxmm; tag: hoverTag; screen: root.screen; anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter } }
            Chrome { id: after; items: root.chrome.after || []; pxmm: root.pxmm; tag: hoverTag; screen: root.screen; anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter } }
            Flickable {
                id: list
                anchors { fill: parent; leftMargin: 18 + (before.width ? before.width + 8 : 0); rightMargin: 18 + (after.width ? after.width + 8 : 0) }
                contentWidth: row.width
                clip: true
                flickableDirection: Flickable.HorizontalFlick
                boundsBehavior: Flickable.StopAtBounds
                Row {
                    id: row
                    height: list.height
                    spacing: 8
                    Repeater {
                        model: root.windows
                        DockEntry {
                            required property var modelData
                            anchors.verticalCenter: parent.verticalCenter
                            client: modelData
                            tag: hoverTag
                            pending: root.pending.indexOf(modelData.id) >= 0
                            onChosen: function(shift) { root.choose(modelData, shift); }
                        }
                    }
                }
                WheelHandler {
                    onWheel: function(event) {
                        const d = event.pixelDelta.x || event.pixelDelta.y || (event.angleDelta.x || event.angleDelta.y) / 2;
                        list.contentX = Math.max(0, Math.min(list.contentWidth - list.width, list.contentX - d));
                        event.accepted = true;
                    }
                }
            }
        }
    }
    // Skin elements in a row, each centred on its anchor in the dock's height.
    component Chrome: Row {
        id: chromeRow
        property var items: []
        property real pxmm: 3.6          // inline components cannot see the window's ids: passed in
        property var tag: null
        property var screen: null
        spacing: 8
        height: Settings.railWidth
        Repeater {
            model: chromeRow.items
            Item {
                id: cell
                required property var modelData
                readonly property string elementId: typeof modelData === "string" ? modelData : modelData.element || ""
                width: el.width - 2 * el.margin; height: chromeRow.height
                SkinElement {
                    id: el
                    elementId: cell.elementId
                    pxmm: chromeRow.pxmm; tag: chromeRow.tag
                    context: ({screen: chromeRow.screen})
                    x: (cell.width - width) / 2
                    y: cell.height / 2 - anchorY
                }
            }
        }
    }
}
