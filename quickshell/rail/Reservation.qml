import QtQuick
import Quickshell
import Quickshell.Wayland
// An invisible surface that only reserves space at one edge. The visible rail and dock place
// themselves explicitly (exclusion ignored), so they never depend on which surface the
// compositor arranged first; these hold the space windows must avoid.
PanelWindow {
    property string edge: "left"
    property int zone: 0
    anchors { left: edge !== "right"; right: edge !== "left"; top: edge !== "bottom"; bottom: edge !== "top" }
    implicitWidth: 1; implicitHeight: 1
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: zone
    color: "transparent"
    focusable: false
    mask: Region {}
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "illuminated-reserve"
}
