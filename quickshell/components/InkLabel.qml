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
    font.pixelSize: variant === "heading" ? Settings.option("typography.heading") : variant === "small" ? Settings.smallPixelSize : variant === "display" ? Settings.option("typography.display") : Settings.fontPixelSize
    textFormat: Text.PlainText
    wrapMode: Text.WordWrap
}
