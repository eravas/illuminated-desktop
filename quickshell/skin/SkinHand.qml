import QtQuick
// A hand a skin adds: dealt by an object (run("deal:<name>")) or listed in rail.hands.
QtObject {
    required property string name
    property string label: name
    property string glyph: label.charAt(0)
    property var cards: []
    property string sheet: ""
    property string show: "always"
}
