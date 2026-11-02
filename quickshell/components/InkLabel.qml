import QtQuick
import QtQuick.Controls
import "../theme"
import "../config"
// Text on vellum: Alegreya for body and small; the card face (blackletter by default, Germania
// One or sans under the reading presets) for headings and display.
Label {
    property string variant: "body"     // body | small | heading | display
    readonly property bool lettered: variant === "heading" || variant === "display"
    color: variant === "small" ? Theme.mutedInk : Theme.ink
    font.family: lettered ? Theme.cardFamily : Theme.serifFamily
    font.bold: lettered && Theme.cardBold
    font.pixelSize: variant === "heading" ? Settings.headingPixelSize : variant === "small" ? Settings.smallPixelSize : variant === "display" ? Settings.displayPixelSize : Settings.fontPixelSize
    textFormat: Text.PlainText
    wrapMode: Text.WordWrap
}
