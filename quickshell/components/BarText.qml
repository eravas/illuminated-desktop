import QtQuick
import "../config"
import "../theme"

Text {
    color: Theme.ink
    font.family: Settings.fontFamily
    font.pixelSize: Settings.fontPixelSize
    textFormat: Text.PlainText // window titles are untrusted text, never markup
    elide: Text.ElideRight
    verticalAlignment: Text.AlignVCenter
    maximumLineCount: 1
}
