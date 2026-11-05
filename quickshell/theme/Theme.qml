pragma Singleton
import QtQuick
import Quickshell
import "../config"
import "../config/Reading.js" as Reading
import "../materials/Fields.js" as Fields
import "../materials/VellumPaint.js" as VellumPaint
// Herbarium: material colours come from the active palette (they change per
// mode); semantic colours come from [semantic] (one value in every mode).
Singleton {
    id: root
    // An unknown mode (for example a stale "highContrast" in ui.json) renders as dark.
    readonly property string mode: Settings.option("palettes." + Settings.appearance, null) ? Settings.appearance : "dark"
    readonly property string otherMode: mode === "light" ? "dark" : "light"
    readonly property bool light: mode === "light"
    readonly property color paper: Settings.color("paper")
    readonly property color cardstock: Settings.color("cardstock")
    readonly property color sunken: Settings.color("sunken")
    readonly property color ink: Settings.color("ink")
    // Secondary ink reaches ≥ 7:1 under the "high" option (Legibility, Accessibility).
    readonly property color mutedInk: Settings.reading.secondaryInk === "high" ? Settings.color("mutedInkHigh") : Settings.color("mutedInk")
    readonly property color disabledInk: Settings.color("disabledInk")
    readonly property color edge: Settings.color("edge")
    readonly property color fray: Settings.color("fray")
    readonly property color accent: Settings.color("accent")
    readonly property color activePaper: Settings.color("activePaper")
    readonly property color hoverPaper: Settings.color("hoverPaper")
    readonly property color urgent: Settings.color("urgent")
    readonly property color focusCore: Settings.color("focusCore")
    readonly property color focusFringe: Settings.color("focusFringe")
    readonly property int gap: Settings.spacing
    readonly property int radius: Settings.radius
    readonly property int motionDuration: Settings.reducedMotion ? 0 : Settings.option("motion.lift")
    // Display face (card, rail and dock text): Pirata One, Germania One (Legibility) or the
    // sans (Accessibility). Blackletter faces have one weight; only the sans is set bold.
    readonly property string face: Settings.reading.face
    readonly property string cardFamily: face === "sans" ? Settings.fontFamily : face === "germania" ? Settings.legibilityFamily : Settings.blackletterFamily
    readonly property bool cardBold: face === "sans"
    readonly property string serifFamily: Settings.serifFamily
    readonly property real typeScale: Settings.typeScale
    function numeral(n) { return Reading.numeral(n, Settings.reading.numerals); }
    // Material texture amplitude per mode, scaled by the texture option; text-bearing
    // surfaces pass textBearing so Accessibility's "off" applies to them only.
    function textureAmp(textBearing) {
        const k = Settings.reading.texture === "full" ? 1 : Settings.reading.texture === "reduced" ? 0.5 : textBearing ? 0 : 0.5;
        return (Fields.TEXTURE_AMPLITUDE[mode] || 0.07) * k;
    }
    // Rail and dock wash: accent mixed toward the vellum, gated so mode ink passes 4.5:1.
    readonly property var wash: Settings.reading.wash === "off" ? null : VellumPaint.washTone(String(paper), Settings.accent, String(ink), mode, Settings.washStrength, textureAmp(true))
    readonly property string colourVision: Settings.colourVision
    // Scoped mode inversion: a material role resolved against the opposite mode.
    function material(name, inverted) {
        const value = Settings.option("palettes." + (inverted ? otherMode : mode) + "." + name, null);
        return value !== null ? value : Settings.color(name);
    }
    function semantic(name) { return Settings.option("semantic." + name); }
    // Everything CardModel.js needs, as one plain object.
    readonly property var cardColours: ({
        cardstock: cardstock, cardstockTonal: Settings.color("cardstockTonal"), ink: ink, edge: edge,
        edgeInverted: material("edge", true), sleepCard: Settings.color("sleepCard"), sleepInk: Settings.color("sleepInk"),
        onFill: semantic("onFill"), volume: semantic("volume"), volumeMuted: semantic("volumeMuted"),
        brightness: semantic("brightness"), power: semantic("power"), battery: semantic("battery"),
        batteryTonal: semantic("batteryTonal"), bluetooth: semantic("bluetooth"), copper: semantic("copper"),
        verdigris: semantic("verdigris"), critical: semantic("critical"), criticalTonal: semantic("criticalTonal"), silver: semantic("silver")
    })
}
