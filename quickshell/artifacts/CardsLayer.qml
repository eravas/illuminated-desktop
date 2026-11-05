pragma ComponentBehavior: Bound
import QtQuick
import "../skin"
import "../theme"
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "Geometry.js" as Geometry
import "../components"
import "../config"
import "../services"
import "../pages"
import "kinds/Kinds.js" as Kinds
PanelWindow {
    id: root
    property alias cardItems: cards
    property string displayGroup: ""
    property bool deployed: false
    property real phase: deployed ? 1 : 0
    property int page: 0
    property int pendingPage: 0
    property int selectedIndex: 0
    onSelectedIndexChanged: if (!Navigation.sheet) Qt.callLater(function() { root.focusSelection(); })
    // Membership, orientation and sheets come from [groups] and [cards] in config.
    readonly property var groupSpec: Settings.group(displayGroup) || ({cards: [], sheet: ""})
    readonly property var kinds: groupSpec.cards || []
    // Hands travel in from the left at the dealing initial's height. Space the rail and a
    // permanent dock take is kept clear.
    readonly property int chromeLeft: Settings.enableRail ? Settings.railReserved : 0
    readonly property int chromeTop: Settings.enableDock && Settings.dockMode(screen ? screen.name : "", height) === "permanent" ? Settings.dockReserved : 0
    readonly property var deckOptions: ({cardWidth:Settings.cardWidth, landscapeWidth:Settings.landscapeCardWidth, gap:Math.max(Settings.cardGap, Settings.selectionLift + 8), margin:Settings.cardMargin, rotation:Math.min(7,Math.abs(Settings.cardRotation)), aligned:Settings.deckAligned, lift:Settings.selectionLift})
    readonly property var deckItems: kinds.map(kind => ({landscape: Kinds.landscape(kind) || Settings.card(kind).orientation === "landscape"}))   // built-in kinds, or a skin card's own
    readonly property var layout: Geometry.dealLeft(width, height, Navigation.lane, deckItems, page, chromeLeft, chromeTop, deckOptions)
    readonly property bool active: Navigation.group !== "" || Navigation.device !== ""
    screen: Navigation.screen || Quickshell.screens[0]
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "illuminated-cards"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: active ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    // Input passes through to the rail so it stays usable while a hand is out.
    mask: Region { x: root.chromeLeft; y: 0; width: Math.max(0, root.width - x); height: Math.max(0, root.height - y) }
    color: "transparent"
    visible: active || phase > 0 || sheet.progress > 0 || Navigation.device !== ""
    function sync() {
        if (Navigation.group === displayGroup && Navigation.group !== "" && page === pendingPage) deployed = true;
        else if (phase <= 0) {
            displayGroup = Navigation.group; page = pendingPage; selectedIndex = 0;
            if (displayGroup) Qt.callLater(function() { root.deployed = true; focusScope.forceActiveFocus(); });
        } else deployed = false;
    }
    function turnPage(delta) { pendingPage = Math.max(0, Math.min(layout.pages - 1, page + delta)); sync(); }
    function selection() { const placement = cards.itemAt(selectedIndex) as Placement; return placement ? placement.card : null; }
    // Turn every flipped card back (cancelling any confirmation); false if none was.
    function flipBack() {
        let any = false;
        for (let i = 0; i < cards.count; i++) { const placement = cards.itemAt(i) as Placement; if (placement && placement.card.flipped) { placement.card.flipped = false; any = true; } }
        return any;
    }
    function focusSelection() { const card = selection(); if (card) card.focusFace(); else focusScope.forceActiveFocus(); }
    onPhaseChanged: if (phase <= 0) sync()
    Behavior on phase { NumberAnimation { duration: Motion.deploy + Motion.stagger * Math.max(0, root.layout.cards.length - 1); easing.type: Motion.easing } }
    Connections { target: Navigation; function onGroupChanged() { SessionState.cancel(); root.pendingPage = 0; root.sync(); const spec = Settings.group(Navigation.group); if (spec && !spec.cards.length && spec.sheet && !Navigation.sheet) Navigation.expand(spec.sheet); } function onSheetChanged() { if (Navigation.sheet) Qt.callLater(function() { focusScope.forceActiveFocus(); }); else Qt.callLater(function() { root.focusSelection(); }); } }
    Connections { target: Quickshell; function onScreensChanged() { if (Navigation.screen && Quickshell.screens.indexOf(Navigation.screen) < 0) Navigation.dismiss(); } }
    onVisibleChanged: if (visible) Qt.callLater(function() { focusScope.forceActiveFocus(); })
    Component.onDestruction: { Navigation.dismiss(); SessionState.cancel(); }
    // A click on the desk turns a flipped card back first; a second click closes the deck.
    MouseArea { anchors.fill: parent; onClicked: if (Navigation.sheet || !root.flipBack()) Navigation.dismiss() }
    FocusScope {
        id: focusScope
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: { if (Navigation.sheet && root.kinds.length) Navigation.sheet = ""; else if (Navigation.sheet || !root.flipBack()) Navigation.dismiss(); }
        Keys.onDownPressed: function(event) { if (Navigation.sheet || (root.selection() && root.selection().flipped)) { event.accepted = false; return; } root.selectedIndex = (root.selectedIndex + 1) % Math.max(1, root.layout.cards.length); }
        Keys.onUpPressed: function(event) { if (Navigation.sheet || (root.selection() && root.selection().flipped)) { event.accepted = false; return; } root.selectedIndex = (root.selectedIndex + root.layout.cards.length - 1) % Math.max(1, root.layout.cards.length); }
        Keys.onPressed: function(event) { if (event.key === Qt.Key_PageDown) { root.turnPage(1); event.accepted = true; } else if (event.key === Qt.Key_PageUp) { root.turnPage(-1); event.accepted = true; } }
        Keys.onReturnPressed: function(event) { const card = root.selection(); if (!Navigation.sheet && card && !card.flipped) card.activate(); else event.accepted = false; }
        Keys.onRightPressed: function(event) { const card = root.selection(); if (!Navigation.sheet && card) card.flipped = true; else event.accepted = false; }
        Keys.onLeftPressed: function(event) { const card = root.selection(); if (!Navigation.sheet && card) card.flipped = false; else event.accepted = false; }
        component Placement: Item {
                id: placement
                required property var modelData
                required property int index
                // Skin cards ("skin:<id>", docs/SKINS.md) or the built-in service cards.
                readonly property var card: cardLoader.item
                readonly property string kind: root.kinds[placement.modelData.index] || ""
                readonly property real amount: Geometry.clamp(root.phase * (1 + (root.layout.cards.length - 1) * 0.16) - index * 0.16, 0, 1)
                readonly property bool sideways: modelData.offscreenX !== undefined
                readonly property real travelX: sideways ? modelData.offscreenX + (modelData.x - modelData.offscreenX) * amount : modelData.x
                readonly property real travelY: sideways ? modelData.y : modelData.offscreenY + (modelData.y - modelData.offscreenY) * amount
                // Whole pixels while dealing too when grid-aligned, so text never lands between pixels.
                x: Settings.deckAligned ? Math.round(travelX) : travelX
                y: Settings.deckAligned ? Math.round(travelY) : travelY
                width: modelData.width; height: modelData.height
                z: root.selectedIndex === index ? 100 : 1
                Loader {
                    id: cardLoader
                    anchors.fill: parent
                    // "skin:<id>" is a skin card (docs/SKINS.md); anything else a built-in kind.
                    sourceComponent: placement.kind.indexOf("skin:") === 0 ? skinCard : serviceCard
                }
                Component {
                    id: serviceCard
                    ServiceCard {
                        kind: placement.kind
                        aspectRatio: placement.modelData.ratio
                        naturalRotation: placement.modelData.angle
                        selected: root.selectedIndex === placement.index
                        interactive: root.deployed && Navigation.sheet === "" && placement.amount > 0.8
                        onSelectedByUser: root.selectedIndex = placement.index
                    }
                }
                Component {
                    id: skinCard
                    SkinCard {
                        kind: placement.kind
                        aspectRatio: placement.modelData.ratio
                        naturalRotation: placement.modelData.angle
                        selected: root.selectedIndex === placement.index
                        interactive: root.deployed && Navigation.sheet === "" && placement.amount > 0.8
                        onSelectedByUser: root.selectedIndex = placement.index
                    }
                }
            }
        Repeater { id: cards; model: root.layout.cards; delegate: Placement {} }

        Row {
            x: root.chromeLeft + 16
            y: root.height - 40
            spacing: Theme.gap
            visible: root.layout.pages > 1 && Navigation.sheet === ""
            ActionButton { text: "‹"; enabled: root.page > 0; onClicked: root.turnPage(-1) }
            InkLabel { text: (root.page + 1) + "/" + root.layout.pages; anchors.verticalCenter: parent.verticalCenter }
            ActionButton { text: "›"; enabled: root.page < root.layout.pages - 1; onClicked: root.turnPage(1) }
        }
        VellumSheet {
            id: sheet
            objectName: "cards-sheet"
            width: Math.min(Settings.option("dimensions.sheetWidth"), root.width - 24)
            height: Math.min(Settings.option("dimensions.sheetHeight"), root.height - root.chromeTop - 32)
            // Beside the rail at the dealing initial's height.
            x: root.chromeLeft + 12
            y: Math.max(root.chromeTop + 12, Math.min(root.height - height - 12, Navigation.lane - height / 2))
            z: 200
            from: "left"
            offX: x; offY: y
            opened: Navigation.sheet !== "" && root.active
            // Keep content alive during retraction; release only after the sheet closes.
            property string displayed: ""
            onOpenedChanged: if (opened) displayed = Navigation.sheet
            onProgressChanged: if (progress <= 0) displayed = ""
            Connections { target: Navigation; function onSheetChanged() { if (Navigation.sheet) sheet.displayed = Navigation.sheet; } }
            content: Component {
                ColumnLayout {
                    ActionButton { text: root.kinds.length ? "← Cards" : "← Close"; onClicked: { if (root.kinds.length) Navigation.sheet = ""; else Navigation.dismiss(); } }
                    ScrollView {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        contentWidth: availableWidth
                        Loader {
                            width: parent.width
                            sourceComponent: ({audio: audioPage, network: networkPage, bluetooth: bluetoothPage, media: mediaPage, history: historyPage, settings: settingsPage, tray: trayPage, brightness: brightnessPage, clipboard: clipboardPage})[sheet.displayed] || null
                        }
                    }
                }
            }
        }
    }
    Component { id: audioPage; AudioPage {} }
    Component { id: networkPage; NetworkPage {} }
    Component { id: bluetoothPage; BluetoothPage {} }
    Component { id: mediaPage; MediaPage {} }
    Component { id: historyPage; HistoryPage {} }
    Component { id: trayPage; TrayPage {} }
    Component { id: settingsPage; SettingsPage {} }
    Component { id: clipboardPage; ClipboardPage {} }
    // A removable device handed over from the rail with its card (SURFACES.md §2a).
    Loader {
        id: deviceHand
        active: Navigation.device !== "" && Navigation.screen === root.screen
        anchors.fill: parent
        z: 150
        source: "../media/DeviceHand.qml"
        onLoaded: item.forceActiveFocus()
    }
    Component {
        id: brightnessPage
        ColumnLayout {
            InkLabel { text: "Luminance"; variant: "heading" }
            InkLabel { text: BrightnessState.error || (BrightnessState.available ? Math.round(BrightnessState.value * 100) + "%" : "No backlight available"); Layout.fillWidth: true }
            LevelSlider { Layout.fillWidth: true; from: 0.01; to: 1; value: BrightnessState.value; enabled: BrightnessState.available; onMoved: BrightnessState.setValue(value) }
        }
    }
}
