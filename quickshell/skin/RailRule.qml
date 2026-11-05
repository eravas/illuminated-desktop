import QtQuick
import QtQuick.Layouts
import "../theme"
// A hairline across the rail, between groups.
Item {
    property var host: null
    Layout.fillWidth: true
    implicitHeight: 13
    Rectangle { anchors.centerIn: parent; width: 28; height: 1; color: Theme.edge }
}
