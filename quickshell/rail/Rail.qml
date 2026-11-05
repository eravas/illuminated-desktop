pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.UPower
import "../theme"
import "../config"
import "../artifacts"
import "../services"
import "../compositors"
import "../materials"
import "../artifacts/CardModel.js" as CardModel
import "../materials/DeviceGeometry.js" as Geo
import "../skin"
// The left rail (DESIGN.md §6): a floating inset vellum strip with the accent wash. What lies on
// it, in what order, is the skin's Rail.qml (docs/SKINS.md): a RailLayout of the skin's objects
// and the shell's parts, and a foot object anchored at the screen's bottom-left corner.
// Permanent; the space is held by a separate Reservation surface so placement never depends on
// mapping order.
PanelWindow {
    id: root
    anchors { left: true; top: true; bottom: true }
    implicitWidth: Settings.railInset + Settings.railWidth + 8
    exclusionMode: ExclusionMode.Ignore
    focusable: false
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "illuminated-rail"
    // Input: the vellum strip, plus wherever a device object lies (it may sit off the strip).
    mask: Region { item: strip; Region { item: bay.hitArea } Region { item: footHost } }

    DesktopContext { id: desktop; shellScreen: root.screen }
    readonly property var battery: UPower.displayDevice
    readonly property bool batteryPresent: battery && battery.ready && battery.isPresent
    // Life size: the same scale as the removable media.
    readonly property real pxmm: Geo.pxPerMm(Settings.mediaScale, screen ? screen.physicalPixelDensity : 0, screen ? screen.devicePixelRatio : 1)
    readonly property alias tag: hoverTag
    readonly property alias desktop: desktopContext
    function shown(name) {
        const spec = SkinStore.group(name);
        if (!spec) return false;
        return spec.show === "battery" ? batteryPresent : spec.show === "player" ? MediaState.player !== null : true;
    }
    // Every hand and sheet the rail opens goes through the action registry (skin/Actions.qml).
    function deal(name, item) { Actions.run("deal:" + name, {screen: root.screen, y: item.mapToItem(null, 0, item.height / 2).y}); }
    function handLabel(name) { return (SkinStore.group(name).label || name) + ": " + (SkinStore.group(name).cards || []).map(k => SkinStore.card(k).title || k).join(", "); }
    // Removable media: the skin's MediaBay item marks where the bay starts.
    property Item bayAnchor: null
    readonly property real bayHeight: bay.bay

    DesktopContext { id: desktopContext; shellScreen: root.screen }
    Tag { id: hoverTag; host: root }

    Vellum {
        id: strip
        x: Settings.railInset; y: 8
        width: Settings.railWidth; height: root.height - 16
        offX: x; offY: y
        horizontal: false
        Loader {
            id: layout
            objectName: "rail-layout"
            anchors { fill: parent; topMargin: 10; bottomMargin: Math.max(10, footHost.height - 8) }
            source: SkinStore.qml("Rail.qml")
            onLoaded: item.rail = root
            onStatusChanged: if (status === Loader.Error) console.warn("illuminated skin: Rail.qml does not load:", source)
        }
    }
    // The foot: the layout's foot object, its anchor at the screen's bottom-left corner.
    readonly property Item foot: layout.item ? layout.item.foot : null
    onFootChanged: if (foot) { foot.parent = footHost; foot.x = Qt.binding(() => -foot.anchor[0] * foot.unit); foot.y = Qt.binding(() => footHost.height - foot.anchor[1] * foot.unit); }
    Item {
        id: footHost
        x: 0; y: root.height - height
        width: root.foot && root.foot.visible ? Math.max(0, root.foot.width - root.foot.anchor[0] * root.foot.unit + root.foot.shadowMargin) : 0
        height: root.foot && root.foot.visible ? Math.max(0, root.foot.anchor[1] * root.foot.unit + root.foot.shadowMargin) : 0
    }
    // Devices lie on top of the rail, so they come after (above) the strip.
    DeviceBay {
        id: bay
        visible: Settings.option("features.media")
        x: 0; y: 0; width: root.width; height: root.height
        screen: root.screen; tag: hoverTag
        bayTop: root.bayAnchor ? strip.y + layout.y + root.bayAnchor.y : root.height
    }
}
