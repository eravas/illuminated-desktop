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
// it, in what order, comes from the skin (docs/SKINS.md, "rail"): elements (objects you can
// press), system parts (workspaces, hands without an element, removable media, clock, rules,
// spacer) and a foot element anchored at the screen's bottom-left corner. Permanent; the space
// is held by a separate Reservation surface so placement never depends on mapping order.
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
    function shown(name) {
        const spec = Settings.group(name);
        if (!spec) return false;
        return spec.show === "battery" ? batteryPresent : spec.show === "player" ? MediaState.player !== null : true;
    }
    // Every hand and sheet the rail opens goes through the action registry (skin/Actions.qml).
    function deal(name, item) { Actions.run("deal:" + name, {screen: root.screen, y: item.mapToItem(null, 0, item.height / 2).y, from: "left"}); }
    // The skin's rail layout; hands named by elements, and the configured hands left over.
    readonly property var items: (SkinStore.manifest.rail && SkinStore.manifest.rail.items) || []
    readonly property var handsWithElements: items.filter(i => i.hand && i.element && SkinStore.element(i.element)).map(i => i.hand)
    readonly property var footItem: items.find(i => i.foot && SkinStore.element(i.foot)) || null
    // The rail's working end (4 px inside the strip's outer edge), in the strip's coordinates.
    readonly property real workingEnd: Settings.railWidth - 4
    function handLabel(name) { return (Settings.group(name).label || name) + ": " + (Settings.group(name).cards || []).map(k => Settings.card(k).title || k).join(", "); }

    Tag { id: hoverTag; host: root }

    Vellum {
        id: strip
        x: Settings.railInset; y: 8
        width: Settings.railWidth; height: root.height - 16
        offX: x; offY: y
        horizontal: false
        ColumnLayout {
            id: column
            anchors { fill: parent; topMargin: 10; bottomMargin: Math.max(10, footHost.height - 8) }
            spacing: 0
            Repeater {
                model: root.items
                Loader {
                    id: slot
                    required property var modelData
                    required property int index
                    readonly property string kind: modelData.element ? "element" : modelData.system || ""
                    // A hand's element shows only while that hand is on the rail (config) and present.
                    active: kind === "element" ? !!SkinStore.element(modelData.element) && (!modelData.hand || (Settings.railHands.indexOf(modelData.hand) >= 0 && root.shown(modelData.hand)))
                          : ["rule", "workspaces", "hands", "spacer", "media", "clock"].indexOf(kind) >= 0
                    visible: active
                    Layout.fillWidth: true
                    Layout.fillHeight: kind === "spacer" || kind === "workspaces"
                    Layout.minimumHeight: kind === "spacer" ? 4 : kind === "workspaces" && item ? item.rowHeight * 2 : -1
                    Layout.maximumHeight: kind === "workspaces" && item ? Math.max(item.implicitHeight, 0) : Number.POSITIVE_INFINITY
                    Layout.preferredHeight: kind === "media" ? bay.bay : -1
                    sourceComponent: kind === "element" ? elementSlot : kind === "rule" ? rule : kind === "workspaces" ? workspaces
                                   : kind === "hands" ? initials : kind === "media" ? mediaAnchor : kind === "clock" ? clockSlot : spacer
                    onLoaded: if (kind === "media") root.bayAnchor = slot
                }
            }
        }
    }
    property Item bayAnchor: null
    // An element in a slot: its anchor at the working end (place: "end", default) or the strip's
    // centre (place: "center"), on the slot's centre line.
    Component {
        id: elementSlot
        Item {
            id: host
            readonly property var spec: parent ? parent.modelData : ({})
            implicitHeight: el.implicitHeight - 2 * el.margin + 2 * (spec.gap === undefined ? 2 : spec.gap)
            SkinElement {
                id: el
                elementId: host.spec.element || ""
                pxmm: root.pxmm; tag: hoverTag
                context: ({screen: root.screen})
                x: (host.spec.place === "center" ? Settings.railWidth / 2 : root.workingEnd) - anchorX
                y: host.height / 2 - anchorY
            }
        }
    }
    Component { id: rule; Item { implicitHeight: 13; Rectangle { anchors.centerIn: parent; width: 28; height: 1; color: Theme.edge } } }
    Component { id: spacer; Item {} }
    Component { id: mediaAnchor; Item {} }
    Component { id: workspaces; RailWorkspaces { context: desktop; tag: hoverTag } }
    // Configured hands with no element in the skin: illuminated initials.
    Component {
        id: initials
        Column {
            Repeater {
                model: Settings.railHands.filter(n => root.handsWithElements.indexOf(n) < 0 && root.shown(n))
                RailSlot {
                    id: initial
                    required property string modelData
                    width: parent ? parent.width : implicitWidth
                    mark: (Settings.group(modelData).label || modelData).charAt(0).toUpperCase()
                    label: root.handLabel(modelData); tag: hoverTag
                    onActivated: root.deal(modelData, initial)
                }
            }
        }
    }
    Component {
        id: clockSlot
        Item {
            id: clockBox
            implicitHeight: clock.implicitHeight + (date.visible ? date.implicitHeight : 0)
            Text {
                id: clock
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(Time.now, Settings.timeFormat); textFormat: Text.PlainText
                font.family: Theme.cardFamily; font.bold: Theme.cardBold; font.pixelSize: Math.round(21 * Theme.typeScale)
                color: Theme.ink
            }
            Text {
                id: date
                visible: Settings.railShowDate
                anchors { top: clock.bottom; horizontalCenter: parent.horizontalCenter }
                text: Qt.formatDateTime(Time.now, "d MMM"); textFormat: Text.PlainText
                font.family: Theme.serifFamily; font.pixelSize: Math.round(13 * Theme.typeScale)
                color: Theme.mutedInk
            }
            MouseArea { anchors.fill: parent; onClicked: root.deal("notifications", clockBox) }
        }
    }
    // The foot: an element anchored at the screen's bottom-left corner, over the strip's end.
    Item {
        id: footHost
        x: 0; y: root.height - height
        width: foot.visible ? Math.max(0, foot.width - foot.anchorX) : 0
        height: foot.visible ? Math.max(0, foot.anchorY) : 0
        SkinElement {
            id: foot
            visible: root.footItem !== null && valid
            elementId: root.footItem ? root.footItem.foot : ""
            pxmm: root.pxmm; tag: hoverTag
            context: ({screen: root.screen})
            x: -anchorX; y: footHost.height - anchorY
        }
    }
    // Devices lie on top of the rail, so they come after (above) the strip.
    MediaBay {
        id: bay
        visible: Settings.enableMedia
        x: 0; y: 0; width: root.width; height: root.height
        screen: root.screen; tag: hoverTag
        bayTop: root.bayAnchor ? strip.y + column.y + root.bayAnchor.y : root.height
    }
}
