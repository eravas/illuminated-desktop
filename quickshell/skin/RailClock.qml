import QtQuick
import QtQuick.Layouts
import Quickshell
import "../theme"
import "../config"
import "../services"
// The time (clock.timeFormat) and, with rail.showDate, the date; a click deals Correspondence.
Item {
    id: root
    property var host: null
    Layout.fillWidth: true
    implicitHeight: clock.implicitHeight + (date.visible ? date.implicitHeight : 0)
    Text {
        id: clock
        anchors.horizontalCenter: parent.horizontalCenter
        text: Qt.formatDateTime(Time.now, Settings.option("clock.timeFormat")); textFormat: Text.PlainText
        font.family: Theme.cardFamily; font.bold: Theme.cardBold; font.pixelSize: Math.round(21 * Theme.typeScale)
        color: Theme.ink
    }
    Text {
        id: date
        visible: Settings.option("rail.showDate")
        anchors { top: clock.bottom; horizontalCenter: parent.horizontalCenter }
        text: Qt.formatDateTime(Time.now, "d MMM"); textFormat: Text.PlainText
        font.family: Theme.serifFamily; font.pixelSize: Math.round(13 * Theme.typeScale)
        color: Theme.mutedInk
    }
    MouseArea { anchors.fill: parent; onClicked: if (root.host && root.host.rail) root.host.rail.deal("notifications", root) }
}
