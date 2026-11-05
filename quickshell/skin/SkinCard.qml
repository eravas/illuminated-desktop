pragma ComponentBehavior: Bound
import QtQuick
import "../artifacts"
import "../theme"
// A card a skin defines (SkinCardSpec in its Cards.qml): the skin's face and back components,
// and a chin with the title and live value. Same interface as ServiceCard for the deck.
ArtifactCard {
    id: root
    required property string kind           // "skin:<name>"
    readonly property string cardId: kind.indexOf("skin:") === 0 ? kind.slice(5) : kind
    readonly property var spec: SkinStore.skinCards[cardId] || null
    aspectRatio: spec && spec.orientation === "landscape" ? 7 / 5 : 5 / 7
    dogEar: !!spec && !!spec.back
    Accessible.name: (spec ? spec.title : cardId) + (spec && spec.value ? " " + spec.value : "")
    // Clicks: the card takes the pointer (selection, drags); pass a click to the face's object there.
    property Item faceItem: null
    onActivated: {
        if (!faceItem) return;
        const hit = faceItem.childAt(pressX, pressY);
        const target = hit && hit.clicked ? hit : faceItem.clicked ? faceItem : null;
        if (target) target.clicked(Qt.LeftButton);
    }
    front: Component {
        Item {
            id: face
            Loader {
                anchors.fill: parent
                sourceComponent: root.spec ? root.spec.face : null
                onLoaded: { if (item.card !== undefined) item.card = root; root.faceItem = item; }
            }
            Item {   // chin: title left, value right
                visible: !!root.spec && root.spec.chin
                y: face.height * 0.81; width: face.width; height: face.height * 0.19
                readonly property color ink: root.spec && root.spec.ink.a > 0 ? root.spec.ink : Theme.semantic("onFill")
                Text {
                    anchors { left: parent.left; leftMargin: parent.height * 0.25; verticalCenter: parent.verticalCenter }
                    text: root.spec ? root.spec.title : ""; textFormat: Text.PlainText
                    font.family: Theme.cardFamily; font.bold: Theme.cardBold; font.pixelSize: Math.max(10, parent.height * 0.5)
                    color: parent.ink
                }
                Text {
                    anchors { right: parent.right; rightMargin: parent.height * 0.25; verticalCenter: parent.verticalCenter }
                    text: root.spec ? root.spec.value : ""; textFormat: Text.PlainText
                    font.family: Theme.cardFamily; font.bold: Theme.cardBold; font.pixelSize: Math.max(10, parent.height * 0.5)
                    color: parent.ink
                }
            }
        }
    }
    back: spec && spec.back ? spec.back : null
}
