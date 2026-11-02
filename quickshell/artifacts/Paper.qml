import QtQuick
import "../theme"
Rectangle {
    property bool decorated: true
    color: Theme.paper
    border.color: Theme.edge
    border.width: 1
    radius: Theme.radius
    Rectangle { visible: parent.decorated; x: 5; y: 5; width: parent.width - 10; height: parent.height - 10; color: "transparent"; border.color: Theme.edge; opacity: 0.35; radius: Math.max(0, Theme.radius - 1) }
}
