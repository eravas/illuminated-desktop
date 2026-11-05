import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import "../config"
// The base of a skin's objects (docs/SKINS.md, "SkinItem"). The item is the object's box
// (`size`, in mm or px); its art, with the baked shadow, may reach `shadowMargin` beyond it.
// In a RailLayout its anchor sits at the rail's working end (or the strip's centre).
Item {
    id: root
    property string units: "mm"            // "mm": life size on this output; "px": logical px
    property var size: [0, 0]              // in units
    property var anchor: [size[0], size[1] / 2]
    property string place: "end"           // in a RailLayout: "end" (working end) or "center"
    property real gap: 2                   // logical px above and below, in a column
    property real shadowMargin: 6          // logical px of baked shadow around the box
    property string hand: ""               // the hand this object deals; shown only while it is on the rail
    property bool shown: true              // the object's own condition (a battery, a player…)
    property string tag: ""                // hover text, and the accessible name
    property QtObject hitShape: null       // HitRect, HitCircle or HitPolygon in units; null: the box
    readonly property bool hovered: mouse.containsMouse
    readonly property bool pressed: mouse.pressed
    signal clicked(int button)
    signal wheelStep(int direction)        // +1 up, -1 down
    signal doubleClicked()

    // The rail or dock the object is on ({pxmm, screen, tag, handShown(name)}); set by its layout.
    property var host: null
    // Objects created after their layout (in a Repeater or Loader of the skin's) find it here.
    onParentChanged: if (!host) for (let p = parent; p; p = p.parent) if (p.skinHost === true) { host = p; break; }
    readonly property real pxmm: host && host.pxmm > 0 ? host.pxmm : 1920 / 531
    readonly property real unit: units === "px" ? 1 : pxmm
    function mm(v) { return v * pxmm; }
    function px(v) { return v; }
    // How much larger than the 1× bake the art is drawn, in device px (for FrameImage).
    readonly property real artScale: (units === "px" ? 1 : pxmm / (1920 / 531)) * (Screen.devicePixelRatio > 0 ? Screen.devicePixelRatio : 1)
    // Actions (skin/Actions.qml) with this object's screen and height, as a click would run them.
    function run(action) { return Actions.run(action, {screen: host ? host.screen : null, y: mapToItem(null, 0, height / 2).y}); }

    // Whole logical px, so baked art lands on the pixel grid (no resampling of the dither).
    implicitWidth: Math.round(size[0] * unit)
    implicitHeight: Math.round(size[1] * unit)
    width: implicitWidth; height: implicitHeight
    visible: shown && (!hand || !host || !host.handShown || host.handShown(hand))
    Layout.preferredWidth: implicitWidth
    Layout.preferredHeight: implicitHeight
    Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
    Layout.topMargin: gap; Layout.bottomMargin: gap
    Layout.leftMargin: Math.round((place === "center" ? Settings.railWidth / 2 : Settings.railWidth - 4) - anchor[0] * unit)

    activeFocusOnTab: tag !== ""
    Accessible.role: Accessible.Button
    Accessible.name: tag
    Keys.onReturnPressed: root.clicked(Qt.LeftButton)
    Keys.onSpacePressed: root.clicked(Qt.LeftButton)
    MouseArea {
        id: mouse
        // The box, grown to the hit shape's bounds (a shape may reach past the art).
        readonly property var b: root.hitShape && root.hitShape.bounds ? root.hitShape.bounds() : [0, 0, root.size[0], root.size[1]]
        x: Math.min(0, b[0] * root.unit); y: Math.min(0, b[1] * root.unit)
        width: Math.max(root.width, (b[0] + b[2]) * root.unit) - x
        height: Math.max(root.height, (b[1] + b[3]) * root.unit) - y
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        containmentMask: root.hitShape ? shapeMask : null
        QtObject {
            id: shapeMask
            function contains(point: point): bool { return root.hitShape.contains(Qt.point((point.x + mouse.x) / root.unit, (point.y + mouse.y) / root.unit)); }
        }
        onEntered: if (root.host && root.host.tag && root.tag) root.host.tag.show(root, root.tag, root.host.tagSide || "right")
        onExited: if (root.host && root.host.tag) root.host.tag.hide()
        onClicked: mouse => root.clicked(mouse.button)
        onDoubleClicked: root.doubleClicked()
        onWheel: wheel => { if (wheel.angleDelta.y !== 0) root.wheelStep(wheel.angleDelta.y > 0 ? 1 : -1); else wheel.accepted = false; }
    }
}
