import QtQuick
import Quickshell
import "artifacts"
Scope {
    CardsLayer {}
    Component.onCompleted: Navigation.open("levels", Quickshell.screens[0])
}
