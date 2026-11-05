pragma ComponentBehavior: Bound
import QtQuick
import "../artifacts"
import "../materials"
import "../theme"
import "../config"
import "../services"
import "../components"
import "../artifacts/CardModel.js" as CardModel
// The device card (SURFACES.md §2a): plain cardstock; used space as a silver foil fill
// rising bottom-up; the chin carries the label and used/total. The face lists the actions in
// blackletter, centred. Destructive actions flip the card to the Shut Down template
// ("Confirm?" with the action beneath); the fill continues across the back. Rename and
// Properties use the back too. A locked (LUKS) device asks for its passphrase on the face.
ArtifactCard {
    id: root
    required property var device
    aspectRatio: 5 / 7
    readonly property var geo: CardModel.layout(width, height)
    readonly property real k: geo.k
    readonly property var use: RemovableMedia.usage[device.id] || null
    readonly property real used: use ? use.used / use.size : -1
    readonly property var surface: CardModel.device({used: device.mounted && use ? used : null, busy: !!RemovableMedia.busy[device.id], failed: !!RemovableMedia.errors[device.id]}, Theme.cardColours).surface
    readonly property var textWash: surface.wash
    readonly property real pad: geo.frame + 6 * k
    property string backMode: ""            // confirm | rename | properties
    property string pendingAction: ""
    signal done()
    function act(name) {
        const id = device.id;
        if (name === "Open") { RemovableMedia.open(id); done(); }
        else if (name === "Eject" || name === "Unmount") { RemovableMedia.eject(id); done(); }
        else if (name === "Rename") { backMode = "rename"; flipped = true; }
        else if (name === "Properties") { backMode = "properties"; flipped = true; }
        else if (name === "Format") { backMode = "confirm"; pendingAction = "Format"; flipped = true; expiry.restart(); }
    }
    function confirmFromBack() { if (armed && backMode === "confirm" && pendingAction === "Format") { RemovableMedia.format(device.id); flipped = false; done(); } }
    Timer { id: expiry; interval: Settings.confirmTimeout; onTriggered: if (root.backMode === "confirm") root.flipped = false }
    onFlippedChanged: if (!flipped) { backMode = ""; pendingAction = ""; expiry.stop(); }
    readonly property var actions: device.locked ? [] : device.phone ? ["Open", "Eject"] : device.mounted ? ["Open", "Eject", "Rename", "Format", "Properties"] : ["Eject", "Rename", "Format", "Properties"]
    Accessible.name: device.label + ". " + (device.locked ? "Locked" : device.mounted ? "Mounted" : "Not mounted")

    front: Component {
        Item {
            id: frontFace
            readonly property var textFace: ({item: frontFace, ink: root.surface.ink, wash: root.textWash})
            readonly property var plainTextFace: ({item: frontFace, ink: root.surface.ink, wash: null})
            MaterialFace { anchors.fill: parent; surface: root.surface; front: true; artPanel: false }
            Column {
                id: list
                visible: !root.device.locked
                anchors.horizontalCenter: parent.horizontalCenter
                y: (root.geo.chinArea.y - height) / 2
                width: parent.width - 2 * root.pad
                spacing: 6 * root.k
                Repeater {
                    model: root.actions
                    CardAction {
                        id: action
                        required property string modelData
                        face: frontFace.textFace
                        width: list.width; height: 26 * root.k
                        text: modelData; horizontalAlignment: Text.AlignHCenter
                        pixelSize: 22 * root.k
                        enabled: !RemovableMedia.busy[root.device.id]
                        onTriggered: root.act(action.modelData)
                    }
                }
            }
            Column {   // passphrase for a sealed (LUKS) device
                visible: root.device.locked
                anchors.centerIn: parent
                width: parent.width - 2 * root.pad
                spacing: 8 * root.k
                SplitText { face: frontFace.plainTextFace; width: parent.width; height: 26 * root.k; text: "Sealed"; horizontalAlignment: Text.AlignHCenter; pixelSize: 22 * root.k }
                SearchField {
                    id: passphrase
                    width: parent.width
                    echoMode: TextInput.Password
                    placeholderText: "Passphrase"
                    Component.onCompleted: if (root.device.locked) forceActiveFocus()
                    onAccepted: { RemovableMedia.unlock(root.device.id, text); text = ""; }
                }
                CardAction {
                    face: frontFace.plainTextFace
                    width: parent.width; height: 24 * root.k
                    text: RemovableMedia.busy[root.device.id] === "unlock" ? "Breaking the seal…" : "Unlock"; horizontalAlignment: Text.AlignHCenter
                    pixelSize: 18 * root.k
                    onTriggered: { RemovableMedia.unlock(root.device.id, passphrase.text); passphrase.text = ""; }
                }
            }
            Item {   // chin: label left, used / total right
                x: root.geo.chinArea.x + 5 * root.k; y: root.geo.chinArea.y
                width: root.geo.chinArea.width - 10 * root.k; height: root.geo.chinArea.height
                readonly property string value: RemovableMedia.errors[root.device.id] ? "Failed" : RemovableMedia.busy[root.device.id] ? RemovableMedia.busy[root.device.id] + "…" : CardModel.capacity(root.use ? root.use.used : -1, root.use ? root.use.size : root.device.size)
                SplitText { face: frontFace.textFace; id: chinLabel; width: Math.min(implicitWidth, parent.width * 0.55); height: parent.height; text: root.device.label; pixelSize: 17 * root.k }
                SplitText { face: frontFace.textFace; x: chinLabel.width + 6 * root.k; width: parent.width - x; height: parent.height; horizontalAlignment: Text.AlignRight; text: parent.value; pixelSize: 17 * root.k }
            }
        }
    }
    back: Component {
        Item {
            id: rear
            readonly property var textFace: ({item: rear, ink: root.surface.ink, wash: root.textWash})
            readonly property var plainTextFace: ({item: rear, ink: root.surface.ink, wash: null})
            MaterialFace { anchors.fill: parent; surface: root.surface; front: false }
            SplitText { face: rear.textFace; x: root.pad; y: root.pad; width: rear.width - 2 * root.pad; height: 30 * root.k; text: root.device.label; pixelSize: 24 * root.k }
            Item {   // Confirm? (Shut Down template)
                anchors.fill: parent
                visible: root.backMode === "confirm"
                activeFocusOnTab: visible
                Accessible.role: Accessible.Button
                Accessible.name: "Confirm " + root.pendingAction.toLowerCase()
                Keys.onReturnPressed: root.confirmFromBack()
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.confirmFromBack() }
                Column {
                    anchors.centerIn: parent; width: parent.width - 2 * root.pad; spacing: 4 * root.k
                    SplitText { face: rear.textFace; width: parent.width; height: 32 * root.k; text: "Confirm?"; horizontalAlignment: Text.AlignHCenter; pixelSize: 24 * root.k }
                    SplitText { face: rear.textFace; width: parent.width; height: 24 * root.k; text: root.pendingAction; horizontalAlignment: Text.AlignHCenter; pixelSize: 18 * root.k }
                }
            }
            Column {   // Rename
                visible: root.backMode === "rename"
                anchors.centerIn: parent; width: parent.width - 2 * root.pad; spacing: 8 * root.k
                SearchField {
                    id: label
                    width: parent.width
                    text: root.device.label
                    onVisibleChanged: if (visible) { forceActiveFocus(); selectAll(); }
                    onAccepted: { RemovableMedia.rename(root.device.id, text.trim()); root.flipped = false; }
                }
                CardAction { width: parent.width; height: 24 * root.k; text: "Rename"; horizontalAlignment: Text.AlignHCenter;        pixelSize: 18 * root.k
                    face: rear.textFace
                }
            }
            Column {   // Properties
                visible: root.backMode === "properties"
                x: root.pad; y: root.pad + 34 * root.k; width: parent.width - 2 * root.pad; spacing: 2 * root.k
                Repeater {
                    model: [["Kind", root.device.kind], ["Filesystem", root.device.fsType || "—"], ["Size", CardModel.capacity(-1, root.device.size) || "—"],
                            ["Used", root.use ? CardModel.capacity(-1, root.use.used) : "—"], ["Device", root.device.fsDevice || root.device.device || "—"],
                            ["Mounted at", root.device.mountPoint || "—"], ["Model", ((root.device.vendor || "") + " " + (root.device.model || "")).trim() || "—"]]
                    Column {
                        id: prop
                        required property var modelData
                        width: parent.width
                        SplitText { face: rear.textFace; width: prop.width; height: 15 * root.k; text: prop.modelData[0]; pixelSize: 13 * root.k }
                        SplitText { face: rear.textFace; width: prop.width; height: 19 * root.k; text: prop.modelData[1]; pixelSize: 16 * root.k }
                    }
                }
            }
        }
    }
}
