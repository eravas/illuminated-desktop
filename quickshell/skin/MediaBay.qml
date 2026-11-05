import QtQuick
import QtQuick.Layouts
// Where removable media lie on the rail: the shell's device bay starts at this item's top.
Item {
    id: root
    property var host: null
    Layout.fillWidth: true
    Layout.preferredHeight: host && host.rail ? host.rail.bayHeight : 0
    onHostChanged: if (host && host.rail) host.rail.bayAnchor = root
}
