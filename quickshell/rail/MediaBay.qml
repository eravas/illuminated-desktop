pragma ComponentBehavior: Bound
import QtQuick
import "../skin"
import Quickshell
import "../config"
import "../materials"
import "../artifacts"
import "../services"
import "../materials/DeviceGeometry.js" as Geo
// Removable media on the rail, just above the tray (SURFACES.md §2a). One device is shown;
// scrolling over it cycles. Unmounted devices stand faint along the screen edge and take no
// rail space; a mounted one pivots in and, after a short delay, opens its footprint (`bay`)
// so the rail items above move up. The object lies over the rail and wins overlapping clicks.
Item {
    id: root
    property var screen: null
    property var tag: null
    property real bayTop: 0                      // window y where the bay starts
    readonly property var devices: RemovableMedia.devices
    property int index: 0
    readonly property var current: devices.length ? devices[Math.min(index, devices.length - 1)] : null
    readonly property var rail: Geo.railGeometry(Settings.railInset, Settings.railWidth)
    readonly property bool compact: Settings.mediaScale === "compact"
    readonly property real pxmm: Geo.pxPerMm(Settings.mediaScale, screen ? screen.physicalPixelDensity : 0, screen ? screen.devicePixelRatio : 1)
    readonly property bool engaged: !!current && (current.mounted || current.locked || !!RemovableMedia.engaged[current.id])
    readonly property real wantedBay: engaged ? Geo.bay(Geo.device(current.kind, SkinStore.version), pxmm, rail, compact) : 0
    property real bay: 0                         // what the rail reserves; follows wantedBay after ~300 ms
    readonly property real cy: bayTop + bay / 2
    readonly property var span: current ? Geo.extent(current.kind, engaged ? "mounted" : "unmounted", cy, pxmm, rail, compact) : ({top: 0, bottom: 0})
    // Input region for the device (the rail window's mask includes it).
    readonly property alias hitArea: hit
    onWantedBayChanged: footprint.restart()
    Timer { id: footprint; interval: 300; onTriggered: root.bay = root.wantedBay }
    Behavior on bay { enabled: Settings.reading.transitions === "full"; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    // New devices come to the front.
    property var known: []
    onDevicesChanged: {
        const fresh = devices.findIndex(d => known.indexOf(d.id) < 0);
        if (fresh >= 0 && known.length) index = fresh;
        if (index >= devices.length) index = Math.max(0, devices.length - 1);
        known = devices.map(d => d.id);
    }
    property real slide: 0                       // −1 … 0: sliding offscreen to the left
    function cycle(step) {
        if (devices.length < 2) return;
        if (Settings.reading.transitions !== "full") { index = (index + step + devices.length) % devices.length; return; }
        out.step = step; out.restart();
    }
    SequentialAnimation {
        id: out
        property int step: 1
        NumberAnimation { target: root; property: "slide"; to: -1; duration: 160; easing.type: Easing.InCubic }
        ScriptAction { script: root.index = (root.index + out.step + root.devices.length) % root.devices.length }
        NumberAnimation { target: root; property: "slide"; from: -1; to: 0; duration: 200; easing.type: Easing.OutCubic }
    }
    // Eject: the object slides out past the left edge.
    Connections { target: RemovableMedia; function onEjected(id) { if (root.current && root.current.id === id) leave.restart(); } }
    NumberAnimation { id: leave; target: root; property: "slide"; to: -1.2; duration: 260; easing.type: Easing.InCubic; onFinished: root.slide = 0 }
    // Bounce outward and back on open (never into the app area).
    property real bounce: 0
    SequentialAnimation { id: bounceAnimation
        NumberAnimation { target: root; property: "bounce"; to: -6; duration: 110; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "bounce"; to: 0; duration: 140; easing.type: Easing.InQuad } }
    DeviceObject {
        artVersion: SkinStore.version
        id: object
        visible: !!root.current && Navigation.device !== (root.current ? root.current.id : "")
        x: root.slide * (root.rail.maxX + 20) + root.bounce
        y: 0; width: root.rail.maxX; height: root.height
        kind: root.current ? root.current.kind : "ssd"
        pose: root.engaged ? "mounted" : "unmounted"
        cy: root.cy; pxmm: root.pxmm; compact: root.compact
        locked: !!root.current && root.current.locked
        cracked: false
        opacity: Settings.reading.transitions !== "full" && bounceFlash.running ? 0.6 : (pose === "unmounted" ? 0.55 : 1)
    }
    Timer { id: bounceFlash; interval: 180 }
    Item {
        id: hit
        visible: !!root.current
        x: 0; y: Math.max(0, root.span.top)
        width: !root.current ? 0 : root.engaged ? root.rail.maxX : Math.max(root.rail.unmounted, Settings.targetSize > 24 ? 14 : 10)
        height: !root.current ? 0 : Math.max(Settings.targetSize, Math.min(root.height, root.span.bottom) - y)
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onEntered: root.describe()
            onExited: if (root.tag) root.tag.hide()
            onClicked: function(mouse) {
                const d = root.current; if (!d) return;
                if (mouse.button === Qt.RightButton || d.locked) { Navigation.openDevice(d.id, root.screen, root.cy); return; }
                if (!root.engaged) RemovableMedia.mount(d.id);
                else { RemovableMedia.open(d.id); if (Settings.reading.transitions === "full") bounceAnimation.restart(); else bounceFlash.restart(); }
            }
            property real wheelSum: 0
            onWheel: function(event) {
                wheelSum += event.angleDelta.y || event.angleDelta.x;
                while (Math.abs(wheelSum) >= Settings.option("media.scrollThreshold")) { root.cycle(wheelSum > 0 ? -1 : 1); wheelSum -= Math.sign(wheelSum) * Settings.option("media.scrollThreshold"); }
                event.accepted = true;
            }
        }
    }
    function describe() {
        const d = current; if (!d || !tag) return;
        const state = RemovableMedia.busy[d.id] ? RemovableMedia.busy[d.id] + "…" : RemovableMedia.errors[d.id] || (d.locked ? "locked" : engaged ? "mounted" : "click to mount");
        tag.show(hit, d.label + " · " + state + (devices.length > 1 ? " · " + (index + 1) + " of " + devices.length : ""), "right");
    }
    // Failures and removals without Eject speak up for a few seconds.
    Connections { target: RemovableMedia
        function onErrorsChanged() { if (root.current && RemovableMedia.errors[root.current.id]) { root.describe(); quiet.restart(); } }
        function onWarningChanged() { if (RemovableMedia.warning && root.tag) { root.tag.show(hit, RemovableMedia.warning, "right"); quiet.restart(); } } }
    Timer { id: quiet; interval: 5000; onTriggered: { if (root.tag) root.tag.hide(); RemovableMedia.warning = ""; } }
}
