pragma ComponentBehavior: Bound
import QtQuick
import "../skin"
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../compositors"
import "../theme"
import "../config"
import "../artifacts"
import "../components"
import "../materials"
import "../artifacts/Geometry.js" as Geometry
// The launcher spread (DESIGN.md §8, SURFACES.md launcher): one continuous vellum sheet that
// unfurls flat from its left edge, beside the rail. Left page: six pinned plates (3 × 2,
// placeholder art) under a blackletter Search field. Right page: every application, names in
// the card face, the selected entry under the focus light. The vellum is painted once at full
// size; opening and closing move only the clip.
PanelWindow {
    id: root
    property bool opened: false
    property real progress: opened ? 1 : 0
    property bool everOpened: false
    onOpenedChanged: if (opened) everOpened = true
    readonly property int reservedLeft: Settings.enableRail ? Settings.railReserved : 0
    readonly property int reservedTop: Settings.enableDock ? Settings.dockReserved : 0
    readonly property var geometry: Geometry.spread(width, height, progress,
        {width: Settings.launcherWidth, height: Settings.launcherHeight, left: reservedLeft, top: reservedTop})
    readonly property string motionState: progress <= 0 ? "closed" : progress < 1 ? "unfurling" : "open"
    readonly property string query: search.text.toLowerCase().trim()
    readonly property var matches: DesktopEntries.applications.values.filter(function(entry) {
        return !query || (entry.name + " " + entry.genericName + " " + entry.comment + " " + (entry.keywords || []).join(" ")).toLowerCase().indexOf(query) !== -1;
    }).sort((a, b) => a.name.localeCompare(b.name))
    // Pins: desktop ids from launcher.pins; missing ones leave an empty plate.
    readonly property var pins: [0, 1, 2, 3, 4, 5].map(i => {
        const id = Settings.launcherPins[i];
        return id ? (DesktopEntries.byId(id) || DesktopEntries.heuristicLookup(id)) : null;
    })
    function open() {
        if (!opened) {
            const output = DesktopState.focusedScreen;
            if (output) screen = output;
            search.clear();
            list.currentIndex = 0;
        }
        Navigation.dismiss(); opened = true;
        Qt.callLater(function() { search.forceActiveFocus(); });
    }
    function dismiss() { opened = false; }
    function toggle() { if (opened) dismiss(); else open(); }
    function run(entry) { if (entry) { entry.execute(); dismiss(); } }
    function launch(index) { if (index >= 0 && index < matches.length) run(matches[index]); }
    function move(step) {
        if (!list.count) return;
        list.currentIndex = Math.max(0, Math.min(list.count - 1, list.currentIndex + step));
        list.positionViewAtIndex(list.currentIndex, ListView.Contain);
    }
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "illuminated-launcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    // The rail (and the v6 bar) stay usable while the launcher is open.
    mask: Region { x: root.reservedLeft; y: 0; width: Math.max(0, root.width - x); height: Math.max(0, root.height - y) }
    color: "transparent"
    visible: opened || progress > 0
    Behavior on progress { NumberAnimation { duration: Motion.vellum; easing.type: Motion.easing } }
    onVisibleChanged: if (visible) Qt.callLater(function() { search.forceActiveFocus(); })
    MouseArea { anchors.fill: parent; onClicked: root.dismiss() }

    FocusScope {
        id: spread
        x: root.geometry.x; y: root.geometry.y
        width: root.geometry.width; height: root.geometry.height
        focus: true
        Keys.onEscapePressed: root.dismiss()
        // The reveal: a straight edge travelling right. The canvas reaches 6 px beyond the sheet
        // for the fray and shadow, so the clip does too.
        Item {
            x: -6; y: -6
            width: root.geometry.reveal + (root.progress >= 1 ? 12 : 6); height: parent.height + 12
            clip: true
            Item {
                x: 6; y: 6; width: spread.width; height: spread.height
                // Painted on first open, not at startup; kept, and repainted only if the size changes.
                Loader { anchors.fill: parent; active: root.everOpened
                         sourceComponent: Vellum { washed: false; offX: root.geometry.x; offY: root.geometry.y } }
                MouseArea { anchors.fill: parent; onClicked: search.forceActiveFocus() }
                RowLayout {
                    anchors { fill: parent; margins: 28 }
                    spacing: 32
                    // ── left page ──
                    ColumnLayout {
                        Layout.preferredWidth: Math.round((spread.width - 88) * 0.42)
                        Layout.fillHeight: true
                        spacing: 16
                        SearchField {
                            id: search
                            Layout.fillWidth: true
                            lettered: true
                            placeholderText: "Search"
                            focus: true
                            onTextChanged: list.currentIndex = 0
                            Keys.onDownPressed: root.move(1)
                            Keys.onUpPressed: root.move(-1)
                            Keys.onPressed: function(event) {
                                if (event.key === Qt.Key_PageDown) { root.move(8); event.accepted = true; }
                                else if (event.key === Qt.Key_PageUp) { root.move(-8); event.accepted = true; }
                                else if ((event.modifiers & Qt.AltModifier) && event.key >= Qt.Key_1 && event.key <= Qt.Key_6) { root.run(root.pins[event.key - Qt.Key_1]); event.accepted = true; }
                            }
                            Keys.onEscapePressed: root.dismiss()
                            onAccepted: root.launch(list.currentIndex)
                        }
                        GridLayout {
                            Layout.fillWidth: true; Layout.fillHeight: true
                            columns: 2; rowSpacing: 14; columnSpacing: 14
                            Repeater {
                                model: 6
                                Pin {
                                    required property int index
                                    entry: root.pins[index]
                                    artId: Settings.launcherPins[index] || ""
                                    number: index + 1
                                    Layout.fillWidth: true; Layout.fillHeight: true
                                    onActivated: root.run(entry)
                                }
                            }
                        }
                    }
                    // ── right page ──
                    ColumnLayout {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        spacing: 6
                        ListView {
                            id: list
                            Layout.fillWidth: true; Layout.fillHeight: true
                            clip: true
                            model: root.matches
                            currentIndex: 0
                            boundsBehavior: Flickable.StopAtBounds
                            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                            highlightMoveDuration: Theme.motionDuration > 0 ? 90 : 0
                            highlight: Item {
                                // Inset so the halo's fringe stays inside the list's clip.
                                FocusHalo { anchors { fill: parent; margins: 8 } radius: Theme.radius }
                            }
                            delegate: Entry {
                                required property var modelData
                                required property int index
                                width: list.width
                                entry: modelData
                                selected: index === list.currentIndex
                                onActivated: root.launch(index)
                                onHovered: list.currentIndex = index
                            }
                        }
                        InkLabel { variant: "small"; text: list.count ? list.count + (list.count === 1 ? " application" : " applications") : "No matching applications" }
                    }
                }
            }
        }
    }

    // A pinned application on a plate. Placeholder art until the plates are painted: the
    // application's icon over a pale accent ground, its name below. Empty plates say so.
    component Pin: Item {
        id: pin
        property var entry: null
        property string artId: ""            // desktop id: the skin's pins.<id> image replaces the placeholder
        property int number: 0
        signal activated()
        implicitHeight: 96
        Accessible.role: Accessible.Button
        Accessible.name: entry ? entry.name : "Empty pin " + number
        Rectangle {
            id: plate
            anchors { fill: parent; bottomMargin: 22 }
            radius: Theme.radius
            color: Theme.cardstock
            border.color: Theme.edge
            Rectangle { anchors { fill: parent; margins: 6 } radius: Math.max(0, Theme.radius - 2); color: Theme.accent; opacity: pin.entry ? 0.18 : 0.06 }
            // Your painted plate (docs/SKINS.md, "pins"), cropped to fill; decoded at twice the plate's size.
            Image {
                id: plateArt
                anchors { fill: parent; margins: 6 }
                source: pin.artId && (SkinStore.manifest.pins || {})[pin.artId] ? SkinStore.url(SkinStore.manifest.pins[pin.artId]) : ""
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: Math.round(width * 2); sourceSize.height: Math.round(height * 2)
                asynchronous: true; cache: false
                visible: status === Image.Ready
            }
            Image {
                visible: !plateArt.visible && status === Image.Ready
                anchors.centerIn: parent
                width: Math.min(48, parent.height - 20); height: width
                sourceSize.width: width * 2; sourceSize.height: height * 2
                source: pin.entry && pin.entry.icon ? Quickshell.iconPath(pin.entry.icon, true) : ""
                asynchronous: true
            }
            Text {
                anchors { right: parent.right; bottom: parent.bottom; margins: 6 }
                text: String(pin.number); color: Theme.mutedInk
                font.family: Theme.serifFamily; font.pixelSize: Math.round(11 * Theme.typeScale)
            }
            Rectangle { anchors.fill: parent; radius: Theme.radius; color: Theme.ink; opacity: area.containsMouse && pin.entry ? 0.06 : 0 }
        }
        Text {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 20; verticalAlignment: Text.AlignVCenter; horizontalAlignment: Text.AlignHCenter
            text: pin.entry ? pin.entry.name : "—"; elide: Text.ElideRight; textFormat: Text.PlainText
            font.family: Theme.serifFamily; font.pixelSize: Settings.smallPixelSize
            color: pin.entry ? Theme.ink : Theme.mutedInk
        }
        MouseArea { id: area; anchors.fill: plate; hoverEnabled: true; enabled: pin.entry !== null; cursorShape: Qt.PointingHandCursor; onClicked: pin.activated() }
    }

    // One application: icon, its name in the card face, what it is in Alegreya.
    component Entry: Item {
        id: row
        property var entry: null
        property bool selected: false
        signal activated()
        signal hovered()
        implicitHeight: Math.max(44, Settings.targetSize + 12)
        Accessible.role: Accessible.Button
        Accessible.name: entry ? entry.name : ""
        Image {
            id: icon
            x: 12; anchors.verticalCenter: parent.verticalCenter
            width: 24; height: 24; sourceSize.width: 48; sourceSize.height: 48
            source: row.entry && row.entry.icon ? Quickshell.iconPath(row.entry.icon, true) : ""
            asynchronous: true
        }
        Column {
            anchors { left: icon.right; leftMargin: 10; right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
            Text {
                width: parent.width; elide: Text.ElideRight; textFormat: Text.PlainText
                text: row.entry ? row.entry.name : ""
                font.family: Theme.cardFamily; font.bold: Theme.cardBold; font.pixelSize: Math.round(19 * Theme.typeScale)
                color: Theme.ink
            }
            Text {
                width: parent.width; elide: Text.ElideRight; textFormat: Text.PlainText
                visible: text !== "" && row.selected
                text: row.entry ? (row.entry.genericName || row.entry.comment || "") : ""
                font.family: Theme.serifFamily; font.pixelSize: Settings.smallPixelSize
                color: Theme.mutedInk
            }
        }
        MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onEntered: row.hovered(); onClicked: row.activated() }
    }
}
