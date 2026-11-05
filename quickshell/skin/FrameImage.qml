import QtQuick
// One frame of a baked sheet (scripts/skin/bake-elements.cjs): `file` is the 1× sheet, frames
// in one row; `file` with "-2x" before ".png" is used when the art is drawn more than 1.25×
// larger in device px. Fills the SkinItem it is in, shadow margin included.
Image {
    id: root
    required property url file
    property int count: 1
    property int frame: 0
    readonly property var item: parent
    readonly property real margin: item && item.shadowMargin !== undefined ? item.shadowMargin : 0
    readonly property bool large: item && item.artScale > 1.25
    x: -Math.round(margin); y: -Math.round(margin)
    width: (item ? item.width : 0) + 2 * margin; height: (item ? item.height : 0) + 2 * margin
    source: large ? String(file).replace(/\.png$/, "-2x.png") : file
    // A cell's size in the sheet, as the bake made it: the box at the nominal 1920/531 px/mm
    // (px units: 1), plus the shadow margin, in device px of the 1× or 2× bake.
    readonly property int scaleD: large ? 2 : 1
    readonly property real nominal: item && item.units === "px" ? 1 : 1920 / 531
    readonly property int cellW: item ? Math.max(1, Math.round((item.size[0] * nominal + 2 * margin) * scaleD)) : 1
    readonly property int cellH: item ? Math.max(1, Math.round((item.size[1] * nominal + 2 * margin) * scaleD)) : 1
    sourceClipRect: Qt.rect(Math.max(0, Math.min(count - 1, frame)) * cellW, 0, cellW, cellH)
    smooth: Math.abs(width * scaleD - cellW) > 0.5    // drawn at its baked size: keep the dither crisp
    fillMode: Image.Stretch
    cache: true
}
