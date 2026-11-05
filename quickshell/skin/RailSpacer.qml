import QtQuick
import QtQuick.Layouts
// Takes the rail's free height (pushes what follows to the bottom).
Item {
    property var host: null
    Layout.fillWidth: true
    Layout.fillHeight: true
    Layout.minimumHeight: 4
}
