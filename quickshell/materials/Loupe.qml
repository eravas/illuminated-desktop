import QtQuick
import QtQuick.Effects
import "../theme"
import "../config"
import "../skin"
// A selection loupe from the skin (docs/SKINS.md, "loupes"): the brass image for the mode drawn
// over the magnified content, which shows only through the glass mask. Under the "ring" reading
// option (Accessibility) the fallback ring image is used: no glass, content unmasked inside it.
//
// Public surface:
//   which      "rail" | "dock" (or any loupe a skin defines)
//   default    the content to magnify, centred; scale it yourself (magnification)
// The item is the loupe's box (size from the skin, in logical px; the extra rows below the
// circle hold the contact shadow).
Item {
    id: root
    property string which: "rail"
    default property alias content: inner.data
    readonly property var spec: (SkinStore.manifest.loupes || {})[which] || null
    readonly property bool ring: Settings.reading.loupe === "ring"
    readonly property real diameter: spec ? spec.size[0] : 54
    readonly property string brass: !spec ? "" : SkinStore.url(ring ? (Theme.light ? spec.ring.light : spec.ring.dark) : (Theme.light ? spec.light : spec.dark))
    implicitWidth: spec ? spec.size[0] : 54
    implicitHeight: spec ? spec.size[1] : 57
    // The content, rendered offscreen and shown through the glass (or plainly inside the ring).
    Item {
        id: inner
        width: root.diameter; height: root.diameter
        layer.enabled: !root.ring && !!root.spec
        visible: root.ring || !root.spec
    }
    Image {
        id: glass
        width: root.width; height: root.height
        source: root.spec ? SkinStore.url(root.spec.glass) : ""
        sourceSize.width: Math.round(width * 2); sourceSize.height: Math.round(height * 2)
        visible: false
        layer.enabled: true
    }
    MultiEffect {
        visible: !root.ring && !!root.spec
        x: 0; y: 0; width: root.diameter; height: root.diameter
        source: inner
        maskEnabled: true
        maskSource: glass
        maskThresholdMin: 0.5
        maskSpreadAtMin: 0.5
    }
    Image {
        anchors.fill: parent
        source: root.brass
        sourceSize.width: Math.round(width * 2); sourceSize.height: Math.round(height * 2)
        smooth: true
    }
}
