pragma ComponentBehavior: Bound
import QtQuick
import "../skin"
import "../services"
import "../theme"
import "../config"
import "CardModel.js" as CardModel
import "kinds/Kinds.js" as Kinds
import "kinds"
import "../materials"
// One playing card bound to a service. State → presentation is CardModel.js;
// materials are materials/MaterialFace; this file wires services, clicks and the backs.
// DESIGN.md §8 and DESIGN-SYSTEM.md §3.5–3.12.
ArtifactCard {
    id: root
    required property string kind
    // What the kind is and does (kinds/Kinds.js); title, short, sheet and confirm from config.
    readonly property var meta: Kinds.meta(kind)
    readonly property var spec: Object.assign({}, Settings.card(kind), meta || {})
    // The skin's art for this card (docs/SKINS.md, "cardArt"): {front, dark?, focus?}.
    readonly property var art: (SkinStore.manifest.cardArt || {})[kind] || null
    readonly property string title: spec.title || kind
    // Optional shorter label ([cards.<kind>].short), used only where the title would not fit.
    readonly property string shortTitle: spec.short || ""
    TextMetrics { id: headerMetrics; font.family: Theme.cardFamily; font.bold: Theme.cardBold; font.pixelSize: 24 * root.k; text: root.title }
    readonly property string headerTitle: shortTitle && headerMetrics.advanceWidth > width - 2 * pad ? shortTitle : title
    aspectRatio: meta && meta.orientation === "landscape" ? 7 / 5 : 5 / 7
    frontInset: 0
    backInset: 0
    decorated: false
    readonly property var geo: CardModel.layout(width, height)
    readonly property real k: geo.k
    readonly property var colours: Theme.cardColours

    // ── The kind: service, presentation, activation, back (kinds/) ───────
    readonly property var kindAdapter: kindLoader.item
    Loader { id: kindLoader }
    Component.onCompleted: kindLoader.setSource("kinds/" + (meta ? meta.adapter : "InfoKind") + ".qml", {card: root})
    readonly property real levelValue: kindAdapter ? kindAdapter.level : 0
    readonly property var presentation: kindAdapter ? kindAdapter.presentation : ({surface: CardModel.plain(colours), glyph: "", value: ""})
    readonly property var surface: presentation.surface
    readonly property var backSurface: CardModel.back(kind, surface, colours)
    readonly property var artAdjust: CardModel.art(kind, levelValue, kindAdapter ? kindAdapter.present : true)
    readonly property string percentText: Math.round(levelValue * 100) + ""

    // ── Interaction ──────────────────────────────────────────────────────
    readonly property string interaction: meta ? meta.interaction : "flip"
    readonly property bool hasBack: !!kindAdapter && kindAdapter.back !== null
    direct: interaction === "level"
    dogEar: hasBack && (interaction === "level" || interaction === "toggle")
    dogEarSize: geo.dogEar
    dogEarFrontColour: CardModel.colourAt(backSurface, width - 2, 2, width, height)
    dogEarBackColour: CardModel.colourAt(surface, width - 2, 2, width, height)
    back: hasBack ? backFace : null
    Accessible.name: title + ". " + ((presentation.glyph ? presentation.glyph + " " : "") + presentation.value)

    onActivated: if (!(kindAdapter && kindAdapter.activate()) && back) flipped = !flipped
    onFlippedChanged: if (kindAdapter) kindAdapter.flipped(flipped)
    onSelectedChanged: if (!selected && flipped && kindAdapter) kindAdapter.deselected()
    property real startValue: 0
    onDragStarted: startValue = kindAdapter ? kindAdapter.value : 0
    onAdjusted: function(delta) { if (kindAdapter) kindAdapter.setLevel(startValue + delta); }
    onStepped: function(delta) { if (kindAdapter) kindAdapter.step(delta); }
    Component.onDestruction: if (kindAdapter) kindAdapter.release()

    // ── Front ────────────────────────────────────────────────────────────
    front: Component {
        Item {
            id: face
            MaterialFace {
                anchors.fill: parent; surface: root.surface; front: true
                artSource: root.art ? SkinStore.url(Theme.mode === "dark" && root.art.dark ? root.art.dark : root.art.front || "") : ""
                artFocus: root.art && root.art.focus ? root.art.focus : [0.5, 0.5]
                artLuminance: root.artAdjust.luminance; artSaturation: root.artAdjust.saturation
                cut: root.dogEar ? root.geo.dogEar : 0
                numeral: root.presentation.numeral ? root.percentText : ""
                live: root.dragging
            }
            Item { id: art; x: root.geo.art.x; y: root.geo.art.y; width: root.geo.art.width; height: root.geo.art.height }
            Item {   // chin: label left, glyph and value right; shrinks uniformly before eliding
                id: chin
                readonly property real pad: 5 * root.k
                x: root.geo.chinArea.x + pad; y: root.geo.chinArea.y
                width: root.geo.chinArea.width - 2 * pad; height: root.geo.chinArea.height
                // The short label replaces the title only when title + value would not fit unshrunk.
                readonly property bool useShort: root.shortTitle !== "" && titleMetrics.advanceWidth + valueMetrics.advanceWidth > width - gap
                readonly property string label: root.presentation.numeral ? "" : useShort ? root.shortTitle : root.title
                readonly property string value: (root.presentation.glyph ? root.presentation.glyph + (root.presentation.value ? " " : "") : "") + root.presentation.value
                readonly property var textWash: root.surface.chinFill ? null : root.surface.wash
                readonly property var textFace: ({item: face, ink: root.surface.chinInk, wash: textWash})
                readonly property real base: 17 * root.k
                readonly property real gap: 6 * root.k
                TextMetrics { id: titleMetrics; font.family: Theme.cardFamily; font.bold: Theme.cardBold; font.pixelSize: chin.base; text: root.title }
                TextMetrics { id: labelMetrics; font.family: Theme.cardFamily; font.bold: Theme.cardBold; font.pixelSize: chin.base; text: chin.label }
                TextMetrics { id: valueMetrics; font.family: Theme.cardFamily; font.bold: Theme.cardBold; font.pixelSize: chin.base; text: chin.value }
                readonly property real size: chin.base * Math.max(0.7, Math.min(1, (width - gap) / Math.max(1, labelMetrics.advanceWidth + valueMetrics.advanceWidth)))
                SplitText {
                    id: labelText
                    face: chin.textFace
                    height: parent.height
                    width: Math.min(implicitWidth, chin.value ? parent.width * 0.62 : parent.width)
                    text: chin.label
                    pixelSize: chin.size
                }
                SplitText {
                    face: chin.textFace
                    x: labelText.width + (chin.label ? chin.gap : 0)
                    height: parent.height; width: parent.width - x
                    horizontalAlignment: Text.AlignRight
                    text: chin.value
                    pixelSize: chin.size
                }
            }
        }
    }

    // ── Back ─────────────────────────────────────────────────────────────
    // Continuous with the front's surface. All text is blackletter: header 24,
    // rows 18, stacked values 22 under 15 px labels, Sleep list 22 (× card scale).
    readonly property var backTextWash: backSurface.interior && backSurface.interior.base ? null : backSurface.wash
    Component {
        id: backFace
        Item {
            MaterialFace { anchors.fill: parent; surface: root.backSurface; front: false; cut: root.dogEar ? root.geo.dogEar : 0 }
            Loader { anchors.fill: parent; sourceComponent: root.kindAdapter ? root.kindAdapter.back : null }
        }
    }
    readonly property real pad: geo.frame + 6 * k
    // The default back (kinds/GenericBack.qml), for kinds that do not draw their own.
    readonly property Component genericBack: Component { GenericBack { card: root } }
}
