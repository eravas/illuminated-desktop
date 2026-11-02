pragma ComponentBehavior: Bound
import QtQuick
import "../skin"
import Quickshell.Io
import "../cards/kinds"
import "../services"
import "../theme"
import "../config"
import "CardModel.js" as CardModel
import "../materials"
// One playing card bound to a service. State → presentation is CardModel.js;
// materials are materials/MaterialFace; this file wires services, clicks and the backs.
// DESIGN.md §8 and DESIGN-SYSTEM.md §3.5–3.12.
ArtifactCard {
    id: root
    required property string kind
    // Title, orientation, interaction and sheet come from the [cards] registry in config.
    readonly property var spec: Settings.card(kind)
    // The skin's art for this card (docs/SKINS.md, "cardArt"): {front, dark?, focus?}.
    readonly property var art: (SkinStore.manifest.cardArt || {})[kind] || null
    readonly property string title: spec.title || kind
    // Optional shorter label ([cards.<kind>].short), used only where the title would not fit.
    readonly property string shortTitle: spec.short || ""
    TextMetrics { id: headerMetrics; font.family: Theme.cardFamily; font.bold: Theme.cardBold; font.pixelSize: 24 * root.k; text: root.title }
    readonly property string headerTitle: shortTitle && headerMetrics.advanceWidth > width - 2 * pad ? shortTitle : title
    aspectRatio: spec.orientation === "landscape" ? 7 / 5 : 5 / 7
    frontInset: 0
    backInset: 0
    decorated: false
    readonly property var geo: CardModel.layout(width, height)
    readonly property real k: geo.k
    readonly property var colours: Theme.cardColours

    readonly property var views: ({outputs: outputsBack, network: networkBack, bluetooth: bluetoothBack, battery: batteryBack, menu: menuBack, confirm: confirmBack, generic: genericBack})
    readonly property var adapter: Adapters.create(kind, root, views)
    Loader { id: batteryLoader; active: root.kind === "battery"; source: "../cards/kinds/BatteryDetails.qml" }
    readonly property var batteryDetails: batteryLoader.item
    readonly property bool batteryAvailable: batteryDetails ? batteryDetails.available : false
    readonly property bool externalPower: batteryDetails ? batteryDetails.externalPower : false
    readonly property bool batteryFull: batteryDetails ? batteryDetails.full : false
    readonly property var connected: adapter.connected ? adapter.connected() : []
    readonly property real levelValue: Math.min(1, adapter.level())
    readonly property var presentation: adapter.presentation(colours)
    readonly property var surface: presentation.surface
    readonly property var backSurface: CardModel.back(kind, surface, colours)
    readonly property var artAdjust: CardModel.art(kind, levelValue, batteryAvailable)
    // Flat grey placeholder art; luminance applies now, saturation once art is painted.
    readonly property color artColour: Qt.rgba(0.502 * artAdjust.luminance, 0.502 * artAdjust.luminance, 0.502 * artAdjust.luminance, 1)
    readonly property string percentText: Math.round(levelValue * 100) + ""

    // ── Interaction ──────────────────────────────────────────────────────
    readonly property bool power: spec.interaction === "session"
    readonly property string sessionMode: power ? CardModel.sessionMode(spec) : ""
    readonly property var entries: sessionMode === "menu" ? [kind].concat(spec.alternatives) : []
    readonly property bool owned: power && (SessionState.pending === kind || entries.indexOf(SessionState.pending) >= 0)
    readonly property bool hasBack: adapter.back() !== null
    property bool confirming: false
    property bool inlineArmed: false

    direct: spec.interaction === "level"
    dogEar: hasBack && (spec.interaction === "level" || spec.interaction === "toggle")
    dogEarSize: geo.dogEar
    dogEarFrontColour: CardModel.colourAt(backSurface, width - 2, 2, width, height)
    dogEarBackColour: CardModel.colourAt(surface, width - 2, 2, width, height)
    back: hasBack ? backFace : null
    Accessible.name: title + ". " + ((presentation.glyph ? presentation.glyph + " " : "") + presentation.value)

    // Runs a session action now; the deck closes once the command has started.
    function act(action) {
        SessionState.select(action);
        if (SessionState.pending !== action) return;
        confirming = true;
        const started = SessionState.confirm();
        confirming = false;
        // Close the deck, and leave this card face up for the next time it opens.
        if (started) { flipped = false; Navigation.dismiss(); }
    }
    // Shut Down / Reboot back: a click confirms once the arming delay has passed.
    function confirmFromBack() { if (armed && SessionState.pending === kind) act(kind); }
    // Menu entries (Sleep's back): act at once, or confirm inline ("Log out?") when the entry asks.
    function choose(entry) {
        if (Settings.card(entry).confirm === false) { act(entry); return; }
        if (SessionState.pending === entry && inlineArmed) { act(entry); return; }
        SessionState.select(entry);
        inlineArmed = false;
        inlineArm.restart();
    }
    function entryText(entry) {
        const t = Settings.card(entry).title || entry;
        return SessionState.pending === entry && Settings.card(entry).confirm !== false ? CardModel.sentence(t) + "?" : t;
    }
    Timer { id: inlineArm; interval: Settings.confirmArmDelay; onTriggered: root.inlineArmed = true }

    onActivated: adapter.activate()
    onFlippedChanged: {
        if (sessionMode === "confirm") { if (flipped) SessionState.select(kind); else if (owned) SessionState.cancel(); }
        else if (power && !flipped && owned) SessionState.cancel();
        adapter.onFlip(flipped);
    }
    // A confirmation never outlives the card's focus: selecting another card turns it back.
    onSelectedChanged: if (!selected && flipped && power) flipped = false
    Connections {
        target: SessionState
        // Expired, cancelled or replaced by another card's confirmation: turn back (cancel).
        function onPendingChanged() {
            if (root.sessionMode === "confirm" && root.flipped && SessionState.pending !== root.kind && !root.confirming && SessionState.error === "")
                root.flipped = false;
        }
    }
    onDragStarted: startValue = adapter.level()
    property real startValue: 0
    onAdjusted: function(delta) { adapter.setLevel(startValue + delta); }
    onStepped: function(delta) { adapter.step(delta); }
    Component.onCompleted: adapter.onOpen()
    Component.onDestruction: { if (owned) SessionState.cancel(); adapter.cleanup(); }
    readonly property string profileText: batteryDetails ? batteryDetails.profileText : ""
    readonly property string remainingText: batteryDetails ? batteryDetails.remainingText : "—"
    readonly property string chargeLimit: batteryDetails ? batteryDetails.chargeLimit : ""

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
                readonly property real base: 17 * root.k
                readonly property real gap: 6 * root.k
                TextMetrics { id: titleMetrics; font.family: Theme.cardFamily; font.bold: Theme.cardBold; font.pixelSize: chin.base; text: root.title }
                TextMetrics { id: labelMetrics; font.family: Theme.cardFamily; font.bold: Theme.cardBold; font.pixelSize: chin.base; text: chin.label }
                TextMetrics { id: valueMetrics; font.family: Theme.cardFamily; font.bold: Theme.cardBold; font.pixelSize: chin.base; text: chin.value }
                readonly property real size: chin.base * Math.max(0.7, Math.min(1, (width - gap) / Math.max(1, labelMetrics.advanceWidth + valueMetrics.advanceWidth)))
                SplitText {
                    id: labelText
                    height: parent.height
                    width: Math.min(implicitWidth, chin.value ? parent.width * 0.62 : parent.width)
                    text: chin.label
                    ink: root.surface.chinInk; wash: chin.textWash
                    faceWidth: root.width; faceHeight: root.height
                    originX: chin.x + x; originY: chin.y + y
                    family: Theme.cardFamily; pixelSize: chin.size
                }
                SplitText {
                    x: labelText.width + (chin.label ? chin.gap : 0)
                    height: parent.height; width: parent.width - x
                    horizontalAlignment: Text.AlignRight
                    text: chin.value
                    ink: root.surface.chinInk; wash: chin.textWash
                    faceWidth: root.width; faceHeight: root.height
                    originX: chin.x + x; originY: chin.y + y
                    family: Theme.cardFamily; pixelSize: chin.size
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
            Loader {
                anchors.fill: parent
                sourceComponent: root.adapter.back()
            }
        }
    }
    readonly property real pad: geo.frame + 6 * k

    Component {
        id: outputsBack
        Item {
            id: ob
            // Landscape (Sound): Mixer in the right quarter, centred. Portrait (Devices):
            // a quarter column is too narrow for the word, so Mixer is a footer line.
            readonly property bool wide: root.aspectRatio > 1
            readonly property real listWidth: wide ? ob.width * 0.75 - root.pad : ob.width - 2 * root.pad
            CardAction {   // first in focus order: the way out to the full mixer
                id: mixer
                x: ob.wide ? ob.width * 0.75 : root.pad
                width: ob.wide ? ob.width * 0.25 - root.geo.frame : ob.width - 2 * root.pad
                height: implicitHeight
                y: ob.wide ? (ob.height - height) / 2 : ob.height - root.pad - height
                text: "Mixer"; horizontalAlignment: ob.wide ? Text.AlignHCenter : Text.AlignLeft
                ink: root.backSurface.ink; wash: root.backTextWash; faceWidth: root.width; faceHeight: root.height
                originX: x; originY: y; family: Theme.cardFamily; pixelSize: 16 * root.k
                onTriggered: Navigation.expand(root.spec.sheet || "audio")
            }
            SplitText {
                id: obHeader
                x: root.pad; y: root.pad; width: ob.listWidth; height: 30 * root.k
                text: "Output"; ink: root.backSurface.ink; wash: root.backTextWash
                faceWidth: root.width; faceHeight: root.height; originX: x; originY: y
                family: Theme.cardFamily; pixelSize: 24 * root.k
            }
            Column {
                id: obList
                x: root.pad; y: obHeader.y + obHeader.height + 4 * root.k
                width: ob.listWidth
                spacing: 2 * root.k
                Repeater {
                    model: AudioState.outputs.slice(0, Math.max(0, Math.floor(((ob.wide ? ob.height - root.pad : mixer.y) - obList.y) / (24 * root.k))))
                    CardAction {
                        id: outputRow
                        required property var modelData
                        readonly property real level: AudioState.levelOf(modelData)
                        width: obList.width; height: 22 * root.k
                        opacity: modelData === AudioState.sink ? 1 : 0.72
                        text: (level >= 0 ? Math.round(level * 100) + "% " : "") + (modelData.description || modelData.nickname || modelData.name)
                        ink: root.backSurface.ink; wash: root.backTextWash; faceWidth: root.width; faceHeight: root.height
                        originX: obList.x + x; originY: obList.y + y; family: Theme.cardFamily; pixelSize: 18 * root.k
                        onTriggered: AudioState.selectOutput(outputRow.modelData)
                    }
                }
            }
        }
    }

    Component {
        id: networkBack
        Item {
            id: nb
            SplitText {
                id: nbHeader
                x: root.pad; y: root.pad; width: nb.width - 2 * root.pad; height: 30 * root.k
                text: NetworkState.failed ? root.headerTitle + " · Failed" : root.headerTitle
                ink: root.backSurface.ink; faceWidth: root.width; faceHeight: root.height; originX: x; originY: y
                family: Theme.cardFamily; pixelSize: 24 * root.k
            }
            CardAction {   // first in focus order
                id: seeAll
                x: root.pad; y: nb.height - root.pad - height; width: nb.width - 2 * root.pad; height: 24 * root.k
                text: "See All ›"
                ink: root.backSurface.ink; faceWidth: root.width; faceHeight: root.height; originX: x; originY: y
                family: Theme.cardFamily; pixelSize: 18 * root.k
                onTriggered: Navigation.expand(root.spec.sheet || "network")
            }
            Column {
                id: nbList
                x: root.pad; y: nbHeader.y + nbHeader.height + 4 * root.k
                width: nb.width - 2 * root.pad
                spacing: 2 * root.k
                Repeater {
                    // The connected network, then the strongest others, as many as fit (at most 5).
                    model: NetworkState.networks.slice(0, Math.max(0, Math.min(5, Math.floor((seeAll.y - nbList.y) / (22 * root.k)))))
                    CardAction {
                        id: networkRow
                        required property var modelData
                        tabStop: false
                        width: nbList.width; height: 20 * root.k
                        text: (modelData.connected ? "✓ " : "") + modelData.name
                        ink: root.backSurface.ink; faceWidth: root.width; faceHeight: root.height
                        originX: nbList.x + x; originY: nbList.y + y; family: Theme.cardFamily; pixelSize: 17 * root.k
                        onTriggered: if (!networkRow.modelData.connected) NetworkState.connectNetwork(networkRow.modelData, "")
                    }
                }
            }
        }
    }

    Component {
        id: bluetoothBack
        Item {
            id: bb
            SplitText {
                id: bbHeader
                x: root.pad; y: root.pad; width: bb.width - 2 * root.pad; height: 30 * root.k
                text: BluetoothState.failed ? root.headerTitle + " · Failed" : root.headerTitle
                ink: root.backSurface.ink; faceWidth: root.width; faceHeight: root.height; originX: x; originY: y
                family: Theme.cardFamily; pixelSize: 24 * root.k
            }
            CardAction {
                id: devices
                x: root.pad; y: bb.height - root.pad - height; width: bb.width - 2 * root.pad; height: 24 * root.k
                text: "Devices ›"
                ink: root.backSurface.ink; faceWidth: root.width; faceHeight: root.height; originX: x; originY: y
                family: Theme.cardFamily; pixelSize: 18 * root.k
                onTriggered: Navigation.expand(root.spec.sheet || "bluetooth")
            }
            Column {
                id: bbList
                x: root.pad; y: bbHeader.y + bbHeader.height + 4 * root.k
                width: bb.width - 2 * root.pad
                spacing: 2 * root.k
                Repeater {
                    model: root.connected.slice(0, Math.max(0, Math.floor((devices.y - bbList.y) / (22 * root.k))))
                    Item {
                        id: deviceRow
                        required property var modelData
                        width: bbList.width; height: 20 * root.k
                        Text {   // Bluetooth glyph in the left margin, slightly right of its centre
                            x: root.geo.frame / 2 + 1.5 * root.k - width / 2 - bbList.x
                            anchors.verticalCenter: parent.verticalCenter
                            text: "ᛒ"; textFormat: Text.PlainText
                            font.pixelSize: 11 * root.k; color: root.backSurface.ink
                        }
                        SplitText {
                            anchors.fill: parent
                            text: deviceRow.modelData.name
                            ink: root.backSurface.ink; faceWidth: root.width; faceHeight: root.height
                            originX: bbList.x + deviceRow.x; originY: bbList.y + deviceRow.y
                            family: Theme.cardFamily; pixelSize: 17 * root.k
                        }
                    }
                }
            }
        }
    }

    Component {
        id: batteryBack
        Item {
            id: cb
            readonly property bool held: root.externalPower && !root.batteryFull
            SplitText {
                id: cbHeader
                x: root.pad; y: root.pad; width: cb.width - 2 * root.pad; height: 30 * root.k
                text: root.headerTitle; ink: root.backSurface.ink; wash: root.backTextWash
                faceWidth: root.width; faceHeight: root.height; originX: x; originY: y
                family: Theme.cardFamily; pixelSize: 24 * root.k
            }
            Column {
                id: stats
                x: root.pad; y: cbHeader.y + cbHeader.height + 2 * root.k
                width: cb.width - 2 * root.pad
                spacing: 3 * root.k
                Repeater {
                    model: [
                        {label: "Status", value: root.percentText + "% • held", shown: cb.held},
                        {label: "Profile", value: root.profileText, shown: true},
                        {label: "Remaining", value: root.remainingText, shown: root.remainingText !== "—"},
                        {label: "Limit", value: root.chargeLimit, shown: root.chargeLimit !== ""}
                    ].filter(row => row.shown)
                    Column {
                        id: stat
                        required property var modelData
                        width: stats.width
                        SplitText {
                            width: stat.width; height: 17 * root.k
                            text: stat.modelData.label; bold: false
                            ink: root.backSurface.ink; wash: root.backTextWash; faceWidth: root.width; faceHeight: root.height
                            originX: stats.x + stat.x + x; originY: stats.y + stat.y + y
                            family: Theme.cardFamily; pixelSize: 15 * root.k
                        }
                        SplitText {
                            width: stat.width; height: 25 * root.k
                            text: stat.modelData.value
                            ink: root.backSurface.ink; wash: root.backTextWash; faceWidth: root.width; faceHeight: root.height
                            originX: stats.x + stat.x + x; originY: stats.y + stat.y + y
                            family: Theme.cardFamily; pixelSize: 22 * root.k
                        }
                    }
                }
            }
        }
    }

    Component {
        id: menuBack
        Column {   // Sleep / Lock / Log Out, centred, no header
            id: menu
            anchors.centerIn: parent
            width: parent.width - 2 * root.pad
            spacing: 6 * root.k
            Repeater {
                model: root.entries
                CardAction {
                    id: entry
                    required property string modelData
                    width: menu.width; height: 30 * root.k
                    text: root.entryText(modelData)
                    horizontalAlignment: Text.AlignHCenter
                    ink: root.backSurface.ink; faceWidth: root.width; faceHeight: root.height
                    originX: menu.x + x; originY: menu.y + y; family: Theme.cardFamily; pixelSize: 22 * root.k
                    enabled: !SessionState.busy
                    onTriggered: root.choose(entry.modelData)
                }
            }
            Text {   // a refused action (for example Sleep without a returning locker)
                visible: SessionState.error !== ""
                width: menu.width
                text: SessionState.error; textFormat: Text.PlainText
                wrapMode: Text.Wrap; horizontalAlignment: Text.AlignHCenter
                font.family: Settings.fontFamily; font.pixelSize: Settings.smallPixelSize
                color: root.backSurface.ink
            }
        }
    }

    Component {
        id: confirmBack
        Item {
            id: ask
            objectName: "card-confirm"
            activeFocusOnTab: true
            readonly property bool failed: SessionState.error !== "" && !root.owned
            Accessible.role: Accessible.Button
            Accessible.name: "Confirm " + CardModel.sentence(root.title).toLowerCase()
            Keys.onReturnPressed: function(event) { if (!event.isAutoRepeat) root.confirmFromBack(); }
            Keys.onSpacePressed: function(event) { if (!event.isAutoRepeat) root.confirmFromBack(); }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.confirmFromBack() }
            Column {
                id: prompt
                anchors.centerIn: parent
                width: parent.width - 2 * root.pad
                spacing: 4 * root.k
                visible: !ask.failed
                SplitText {
                    width: prompt.width; height: 32 * root.k
                    text: "Confirm?"; horizontalAlignment: Text.AlignHCenter
                    ink: root.backSurface.ink; wash: root.backTextWash; faceWidth: root.width; faceHeight: root.height
                    originX: prompt.x + x; originY: prompt.y + y; family: Theme.cardFamily; pixelSize: 24 * root.k
                }
                SplitText {
                    width: prompt.width; height: 24 * root.k
                    text: CardModel.sentence(root.title); horizontalAlignment: Text.AlignHCenter
                    ink: root.backSurface.ink; wash: root.backTextWash; faceWidth: root.width; faceHeight: root.height
                    originX: prompt.x + x; originY: prompt.y + y; family: Theme.cardFamily; pixelSize: 18 * root.k
                }
            }
            Text {   // a refused command (for example Sleep without a returning locker)
                visible: ask.failed
                anchors.centerIn: parent
                width: parent.width - 2 * root.pad
                text: SessionState.error; textFormat: Text.PlainText
                wrapMode: Text.Wrap; horizontalAlignment: Text.AlignHCenter
                font.family: Settings.fontFamily; font.pixelSize: Settings.smallPixelSize
                color: root.backSurface.ink
            }
        }
    }

    Component {
        id: genericBack
        Item {
            id: gb
            SplitText {
                id: gbHeader
                x: root.pad; y: root.pad; width: gb.width - 2 * root.pad; height: 30 * root.k
                text: root.headerTitle; ink: root.backSurface.ink; wash: root.backTextWash
                faceWidth: root.width; faceHeight: root.height; originX: x; originY: y
                family: Theme.cardFamily; pixelSize: 24 * root.k
            }
            SplitText {
                x: root.pad; y: gbHeader.y + gbHeader.height; width: gb.width - 2 * root.pad; height: 24 * root.k
                text: root.presentation.value; ink: root.backSurface.ink; wash: root.backTextWash
                faceWidth: root.width; faceHeight: root.height; originX: x; originY: y
                family: Theme.cardFamily; pixelSize: 18 * root.k
            }
            CardAction {
                visible: root.spec.sheet !== ""
                x: root.pad; y: gb.height - root.pad - height; width: gb.width - 2 * root.pad; height: 24 * root.k
                text: "Open ›"
                ink: root.backSurface.ink; wash: root.backTextWash; faceWidth: root.width; faceHeight: root.height
                originX: x; originY: y; family: Theme.cardFamily; pixelSize: 18 * root.k
                onTriggered: Navigation.expand(root.spec.sheet)
            }
        }
    }
}
