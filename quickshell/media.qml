import QtQuick
import Quickshell
import "artifacts"
Scope {
    CardsLayer {}
    Component.onCompleted: { Navigation.open("media", Quickshell.screens[0]); Navigation.expand("media"); }
}
