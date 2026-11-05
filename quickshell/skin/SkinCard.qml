import QtQuick
import "../artifacts"
import "../config"
import "../theme"
import "Skin.js" as Skin
// A card a skin defines (docs/SKINS.md, "Cards and hands"): its face and back are skin
// elements scaled to the card, its chin carries live text (title and a value template over shell
// values), and clicks run the face's triggers (regions included). A back makes it flippable
// with the dog-ear (and right-click). Same interface as ServiceCard for the deck.
ArtifactCard {
    id: root
    required property string kind           // "skin:<id>"
    readonly property string cardId: kind.indexOf("skin:") === 0 ? kind.slice(5) : kind
    readonly property var spec: (SkinStore.manifest.cards || {})[cardId] || ({})
    readonly property var values: ShellState.values
    dogEar: !!spec.back
    Accessible.name: (spec.title || cardId) + (spec.value ? " " + Skin.format(spec.value, values) : "")
    onActivated: if (faceElement) { const t = faceElement.targetAt(pressX, pressY) || "#"; faceElement.trigger("click", t); }
    property SkinElement faceElement: null
    front: Component {
        Item {
            SkinElement {
                id: face
                elementId: root.spec.face || ""
                fitWidth: root.width - 2 * margin
                x: 0; y: 0
                Component.onCompleted: root.faceElement = face
                // Clicks come through the card (it takes the pointer for selection and drags).
                enabled: false
            }
            // Chin: title left, value right, in the card face; rect in the element's units.
            Item {
                readonly property var r: root.spec.chin || [0, 0.81 * (face.valid ? face.element.size[1] : 1), face.valid ? face.element.size[0] : 1, 0.19 * (face.valid ? face.element.size[1] : 1)]
                x: face.margin + r[0] * face.unitScale; y: face.margin + r[1] * face.unitScale
                width: r[2] * face.unitScale; height: r[3] * face.unitScale
                visible: root.spec.chin !== false
                Text {
                    anchors { left: parent.left; leftMargin: parent.height * 0.25; verticalCenter: parent.verticalCenter }
                    text: root.spec.title || root.cardId; textFormat: Text.PlainText
                    font.family: Theme.cardFamily; font.bold: Theme.cardBold; font.pixelSize: Math.max(10, parent.height * 0.5)
                    color: root.spec.ink || Theme.semantic("onFill")
                }
                Text {
                    anchors { right: parent.right; rightMargin: parent.height * 0.25; verticalCenter: parent.verticalCenter }
                    text: Skin.format(root.spec.value || "", root.values); textFormat: Text.PlainText
                    font.family: Theme.cardFamily; font.bold: Theme.cardBold; font.pixelSize: Math.max(10, parent.height * 0.5)
                    color: root.spec.ink || Theme.semantic("onFill")
                }
            }
        }
    }
    back: spec.back ? backFace : null
    Component {
        id: backFace
        SkinElement { elementId: root.spec.back || ""; fitWidth: root.width - 2 * margin; context: ({}) }
    }
}
