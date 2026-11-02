import QtQuick
import "../theme"
import "../skin"
import "InitialMark.js" as InitialMark
// An illuminated initial: the fallback icon for a hand with no skin element. The ground is the
// skin's `initial` image (docs/SKINS.md); the letter is live text in the card face with a light
// halo, so it follows the reading preset's face.
Item {
    id: root
    property string mark: "P"          // a letter, or "launcher" | "clipboard" | "tray"
    implicitWidth: 32; implicitHeight: 32
    Image {
        anchors.fill: parent
        source: SkinStore.manifest.initial ? SkinStore.url(SkinStore.manifest.initial) : ""
        sourceSize.width: Math.round(width * 2); sourceSize.height: Math.round(height * 2)
        smooth: false
    }
    RasterCanvas {
        id: raster
        anchors.fill: parent
        onPainting: function(ctx, W, H) {
            ctx.clearRect(0, 0, W, H);
            InitialMark.drawInitialMark(ctx, root.mark, W, raster.dpr, Theme.cardFamily);
        }
    }
    onMarkChanged: raster.repaint()
    Connections { target: Theme; function onCardFamilyChanged() { raster.repaint(); } }
}
