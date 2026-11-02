import QtQuick
import "../theme"
import "../config"
import "FocusTools.js" as FocusTools
import "../materials"
FocusScope {
    id: root
    property real aspectRatio: 5 / 7
    readonly property bool horizontal: aspectRatio > 1
    property Component front
    property real frontInset: Theme.inset
    property Component back
    property real backInset: 10
    // Plain paper behind the faces; service cards draw their own cardstock.
    property bool decorated: true
    // Flip control on the top-right corner (cards whose click does something else).
    property bool dogEar: false
    property real dogEarSize: 18
    property color dogEarFrontColour: Theme.cardstock   // the back's colour, seen from the front
    property color dogEarBackColour: Theme.cardstock    // the front's colour, seen from the back
    // Confirmations: clicks are ignored while the card turns and briefly after.
    property bool armed: false
    property real naturalRotation: 2
    property bool selected: false
    property bool flipped: false
    property bool interactive: true
    property bool direct: false
    property real flipProgress: flipped ? 1 : 0
    property point pressScene: Qt.point(0, 0)
    property real pressY: 0
    property real pressX: 0
    property bool dragging: false
    readonly property bool frontFacing: flipProgress < 0.5
    signal activated()
    signal dragStarted()
    signal adjusted(real delta)
    signal stepped(real delta)
    signal selectedByUser()
    implicitWidth: 150
    implicitHeight: width / aspectRatio
    height: width / aspectRatio
    z: selected ? 100 : 1
    Accessible.role: Accessible.Button
    activeFocusOnTab: true
    onActiveFocusChanged: if (activeFocus) selectedByUser()
    Accessible.onPressAction: activate()
    function activate() { selectedByUser(); activated(); }
    function reset() { flipped = false; dragging = false; }
    function focusFace() { if (flipped) FocusTools.first(backLoader.item); else forceActiveFocus(); }
    onFlipProgressChanged: { if (interactive && flipProgress > .999) focusFace(); }
    onFlippedChanged: {
        armed = false;
        if (flipped) arming.restart(); else arming.stop();
        if (!flipped && interactive) forceActiveFocus();
    }
    Timer { id: arming; interval: Settings.confirmArmDelay; onTriggered: root.armed = root.flipped }
    Behavior on flipProgress { NumberAnimation { duration: Motion.flip; easing.type: Motion.easing } }
    Keys.onReturnPressed: function(event) { if (!flipped) activate(); else event.accepted = false; }
    Keys.onSpacePressed: function(event) { if (!flipped) activate(); else event.accepted = false; }
    Keys.onRightPressed: if (back) flipped = true
    Keys.onLeftPressed: flipped = false
    Item {
        anchors.fill: parent
        // A separate lift preserves the card's natural rotation.
        transform: Translate { y: root.selected ? -Settings.selectionLift : 0; Behavior on y { NumberAnimation { duration: Motion.lift } } }
        rotation: root.naturalRotation
        Item {
            anchors.fill: parent
            // Orthographic projection of Y-axis rotation: avoids the software renderer's
            // broken nested 3D face composition, with the same edge-on geometry.
            transform: Scale { origin.x: root.width / 2; xScale: Math.abs(Math.cos(Math.PI * root.flipProgress)) }
            // Focus light: solid core on the card's rounded edge, dithered fringe beyond (§3.4).
            Loader { anchors.fill: parent; active: root.selected; sourceComponent: FocusHalo { radius: 0.055 * Math.min(root.width, root.height) } }
            // Service cards paint their own cardstock (with rounded corners and the dog-ear cut).
            Paper { anchors.fill: parent; visible: root.decorated; decorated: root.decorated }
            Loader { anchors.fill: parent; anchors.margins: root.frontInset; sourceComponent: root.front; visible: root.frontFacing }
            Loader {
                id: backLoader
                anchors.fill: parent; anchors.margins: root.backInset; sourceComponent: root.back
                visible: !root.frontFacing
                enabled: root.interactive && root.flipProgress > 0.95
            }
            MouseArea {
                objectName: "card-front-pointer"
                anchors.fill: parent
                enabled: root.interactive && root.flipProgress < 0.05
                preventStealing: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                onPressed: function(mouse) {
                    root.pressScene = mapToItem(null, mouse.x, mouse.y); root.pressY = mouse.y; root.pressX = mouse.x; root.dragging = false;
                    root.selectedByUser(); root.forceActiveFocus(); root.dragStarted();
                }
                onPositionChanged: function(mouse) {
                    if (!pressed || !root.direct || pressedButtons !== Qt.LeftButton) return;
                    const scene = mapToItem(null, mouse.x, mouse.y);
                    const dx = scene.x - root.pressScene.x, dy = scene.y - root.pressScene.y;
                    if (Math.hypot(dx, dy) > Settings.dragThreshold) root.dragging = true;
                    if (root.dragging) root.adjusted(root.horizontal ? dx / root.width : -dy / root.height);
                }
                onReleased: function(mouse) {
                    if (!root.dragging) {
                        if (mouse.button === Qt.RightButton && root.back) root.flipped = !root.flipped;
                        else root.activated();
                    }
                    root.dragging = false;
                }
                onCanceled: root.dragging = false
                onWheel: function(wheel) { root.stepped(wheel.angleDelta.y / 120); wheel.accepted = true; }
            }
            DogEar {
                anchors { top: parent.top; right: parent.right }
                visible: root.dogEar && root.back !== null
                enabled: root.interactive && (root.flipProgress < 0.05 || root.flipProgress > 0.95)
                size: root.dogEarSize
                minimumTarget: Settings.targetSize
                colour: root.frontFacing ? root.dogEarFrontColour : root.dogEarBackColour
                edgeColour: Theme.edge
                // The flip is a projected scale, not a mirror, so the corner stays top-right on both faces.
                onTurned: { root.selectedByUser(); root.flipped = !root.flipped; }
            }
        }
    }
}
