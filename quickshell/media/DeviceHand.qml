import QtQuick
import "../skin"
import "../artifacts"
import "../materials"
import "../config"
import "../services"
import "../materials/DeviceGeometry.js" as Geo
// A removable device handed over from the rail (SURFACES.md §2a): the object straightens and
// comes all the way in beside the rail (large ones about the first third), with its card dealt
// just to its right. Escape, a click on the desk or an action puts both away.
FocusScope {
    id: root
    readonly property var device: RemovableMedia.devices.find(d => d.id === Navigation.device) || null
    readonly property var screen: Navigation.screen
    readonly property var rail: Geo.railGeometry(Settings.railInset, Settings.railWidth)
    readonly property real pxmm: Geo.pxPerMm(Settings.mediaScale, screen ? screen.physicalPixelDensity : 0, screen ? screen.devicePixelRatio : 1)
    readonly property real reach: device ? Geo.outReach(Geo.device(device.kind, SkinStore.version), pxmm) : 0
    readonly property real outX: Settings.railReserved + 8 + reach
    property real progress: 0
    Component.onCompleted: progress = 1
    Behavior on progress { enabled: Settings.reading.transitions === "full"; NumberAnimation { duration: Motion.deploy; easing.type: Easing.OutCubic } }
    onDeviceChanged: if (!device) Navigation.dismiss()     // removed while its card was out
    Keys.onEscapePressed: Navigation.dismiss()
    DeviceObject {
        artVersion: SkinStore.version
        visible: !!root.device
        x: (root.progress - 1) * root.outX; y: 0
        width: root.outX + 4; height: root.height
        clip: false
        kind: root.device ? root.device.kind : "ssd"
        pose: "out"; outX: root.outX
        cy: Navigation.lane; pxmm: root.pxmm
        locked: !!root.device && root.device.locked
        animate: false
    }
    DeviceCard {
        id: card
        visible: !!root.device
        device: root.device || ({id: "", label: "", kind: "ssd"})
        width: Settings.cardWidth
        x: root.outX + 18 + (1 - root.progress) * -(root.outX + width)
        y: Math.max(12, Math.min(root.height - height - 12, Navigation.lane - height / 2))
        naturalRotation: Settings.deckAligned ? 0 : -Math.min(3, Settings.cardRotation)
        selected: true
        interactive: root.progress > 0.8
        onDone: Navigation.dismiss()
        Component.onCompleted: forceActiveFocus()
    }
}
