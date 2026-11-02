import Quickshell
import "rail"
import "config"
// The rail and dock on every output, each with the reservation that holds its space.
Scope {
    Variants {
        model: Quickshell.screens
        Scope {
            id: output
            required property var modelData
            Reservation { screen: output.modelData; edge: "left"; zone: Settings.enableRail ? Settings.railReserved : 0 }
            Rail { screen: output.modelData; visible: Settings.enableRail }
            Reservation { screen: output.modelData; edge: "top"; zone: Settings.enableDock && Settings.dockMode(output.modelData.name, output.modelData.height) === "permanent" ? Settings.dockReserved : 0 }
            Dock { screen: output.modelData; visible: Settings.enableDock }
        }
    }
}
