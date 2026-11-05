import QtQuick
// A canary dot or ring with a dark rim (Compose.marker): shape carries the meaning, not only
// colour. `at` and `radius` in the SkinItem's units.
Rectangle {
    id: root
    property var at: [0, 0]
    property real radius_: 1.3
    property bool ring: false
    property color fill: "#FADB2C"
    readonly property var item: parent
    readonly property real r: radius_ * (item ? item.unit : 1)
    x: at[0] * (item ? item.unit : 1) - r - 1; y: at[1] * (item ? item.unit : 1) - r - 1
    width: 2 * r + 2; height: width; radius: width / 2
    color: ring ? "transparent" : fill
    border.width: Math.max(1, ring ? r * 0.55 : 1.5)
    border.color: ring ? fill : Qt.rgba(fill.r * 0.44, fill.g * 0.41, fill.b * 0.2, 1)
}
