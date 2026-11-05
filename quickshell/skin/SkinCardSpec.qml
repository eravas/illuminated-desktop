import QtQuick
// One skin card: its face (a Component filling the card; it gets `card`, the card item) and an
// optional back, a title and a value on the chin. Clicks on the face reach the face's own
// SkinItems; a back makes the card flippable from the dog-ear.
QtObject {
    required property string name
    property string title: name
    property string short: ""
    property string orientation: "portrait"
    property string value: ""              // live text on the chin (bind it to ShellState)
    property color ink: "transparent"      // chin text; transparent: the theme's on-fill ink
    property bool chin: true
    property Component face: null
    property Component back: null
}
