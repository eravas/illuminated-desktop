import QtQuick
// An ink level inside an object (docs/SKINS.md, "InkFill"): picks the frame of a baked sheet
// whose ink is nearest `level`. A sheet holds `variants` runs of steps + 1 frames each (for
// example discharging, charging with canary bands, held); `variant` picks the run.
FrameImage {
    property real level: 0
    property int steps: 24
    property int variants: 1
    property int variant: 0
    count: variants * (steps + 1)
    frame: variant * (steps + 1) + Math.round(Math.max(0, Math.min(1, level)) * steps)
}
