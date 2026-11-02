pragma Singleton
import QtQuick
import "../config"
// Durations in ms; ranges are validated by `illuminated apply`.
QtObject {
    function duration(name) { return Settings.reducedMotion ? 0 : Settings.option("motion." + name); }
    readonly property int easing: ({linear: Easing.Linear, outCubic: Easing.OutCubic})[Settings.option("motion.easing")] || Easing.InOutQuad
    readonly property int greeter: duration("greeter")
    readonly property int deploy: duration("deploy")
    readonly property int stagger: duration("stagger")
    readonly property int lift: duration("lift")
    readonly property int flip: duration("flip")
    readonly property int scroll: duration("scroll")
    readonly property int vellum: duration("vellum")
}
