import QtQuick
import QtQuick.Layouts
import Quickshell
import "../config"
// The rail's layout (docs/SKINS.md, "Rail.qml"): a column the width of the strip. A skin's
// Rail.qml is one RailLayout holding its own objects (SkinItem) and the shell's parts
// (RailRule, RailWorkspaces, RailHands, RailSpacer, MediaBay, RailClock); `foot` is an object
// anchored at the screen's bottom-left corner. The rail sets `rail` when it loads the layout;
// every SkinItem and part inside gets this layout as its `host`.
ColumnLayout {
    id: root
    spacing: 0
    property var rail: null                // set by rail/Rail.qml
    property Item foot: null
    readonly property real pxmm: rail ? rail.pxmm : 0
    readonly property var screen: rail ? rail.screen : null
    readonly property var tag: rail ? rail.tag : null
    readonly property string tagSide: "right"
    readonly property var desktop: rail ? rail.desktop : null
    // The hands objects on this rail deal (RailHands shows the rest as initials).
    property var dealt: []
    function handShown(name) { return !!rail && Settings.railHands.indexOf(name) >= 0 && rail.shown(name); }
    function adopt(item) {
        if (!item) return;
        if (item.host !== undefined && item !== root) item.host = root;
        if (item.hand) dealt = dealt.indexOf(item.hand) < 0 ? dealt.concat([item.hand]) : dealt;
        for (const child of item.children || []) adopt(child);
    }
    onRailChanged: { adopt(root); adopt(foot); }
    onFootChanged: adopt(foot)
    Component.onCompleted: { adopt(root); adopt(foot); }
}
