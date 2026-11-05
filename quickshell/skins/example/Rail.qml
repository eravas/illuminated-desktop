import QtQuick
import qs.skin
// The example rail: a wax seal (it deals a Desk hand of this skin's) where the tray mark was; the
// tray mark moves onto the paper in the foot (this skin's PaperCorner.qml).
RailLayout {
    Seal { objectName: "seal" }
    Nib { objectName: "nib" }
    RailRule {}
    RailWorkspaces {}
    RailRule {}
    Vial { objectName: "vial" }
    Antenna { objectName: "antenna" }
    Converter { objectName: "converter" }
    Matchbox { objectName: "matchbox" }
    RailHands {}
    RailSpacer {}
    MediaBay {}
    RailRule {}
    RailClock {}
    foot: PaperCorner { objectName: "paper" }
}
