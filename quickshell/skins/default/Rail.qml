import QtQuick
import qs.skin
// The default rail, top to bottom. A skin may replace this file, or any one object's file.
RailLayout {
    Tray { objectName: "tray" }
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
