import QtQuick
import "../theme"
import "../materials"
import "../config"
import "FocusTools.js" as FocusTools
// A sheet that unfurls flat (DESIGN-SYSTEM.md §3.13): the vellum is painted once at its full
// size and revealed by a straight edge travelling away from where it was dealt (`from`). No
// roll and no curl is kept at the edge, open or opening. The reveal is a clip, so the
// animation costs no repaint.
Item {
    id: root
    property bool opened: false
    property Component content
    property string from: "top"           // top | left | bottom
    property real offX: 0                 // screen position, for a continuous texture
    property real offY: 0
    property int padding: 20
    property bool solid: Settings.reading.edge === "solid"
    property real progress: opened ? 1 : 0
    property bool everOpened: false
    onOpenedChanged: if (opened) everOpened = true
    readonly property bool settled: progress > 0.999
    readonly property alias item: contentLoader.item
    onSettledChanged: if (settled && opened) FocusTools.first(contentLoader.item)
    visible: progress > 0
    Behavior on progress { NumberAnimation { duration: Motion.vellum; easing.type: Motion.easing } }
    Item {
        id: reveal
        readonly property int m: 6   // Vellum.margin
        readonly property bool vertical: root.from !== "left"
        x: -m
        y: root.from === "bottom" ? -m + root.height * (1 - root.progress) : -m
        width: vertical ? root.width + 2 * m : m + root.width * root.progress + (root.progress > 0.999 ? m : 0)
        height: !vertical ? root.height + 2 * m : m + root.height * root.progress + (root.progress > 0.999 ? m : 0)
        clip: true
        Item {
            x: reveal.m
            y: root.from === "bottom" ? reveal.m - root.height * (1 - root.progress) : reveal.m
            width: root.width; height: root.height
            // Painted on first open, not at startup (the paint is synchronous JavaScript); kept after.
            Loader { anchors.fill: parent; active: root.everOpened
                     sourceComponent: Vellum { washed: false; solid: root.solid; offX: root.offX; offY: root.offY } }
            Loader {
                id: contentLoader
                x: root.padding; y: root.padding
                width: root.width - 2 * root.padding; height: root.height - 2 * root.padding
                sourceComponent: root.content
                enabled: root.opened
            }
        }
    }
}
