pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../config"
import "../rail"
// The hands in rail.hands that no object on this rail deals: illuminated initials.
Column {
    id: root
    property var host: null
    Layout.fillWidth: true
    Repeater {
        model: root.host ? Settings.railHands.filter(n => root.host.dealt.indexOf(n) < 0 && root.host.handShown(n)) : []
        RailSlot {
            id: initial
            required property string modelData
            width: root.width
            mark: (SkinStore.group(modelData).label || modelData).charAt(0).toUpperCase()
            label: root.host.rail.handLabel(modelData); tag: root.host.tag
            onActivated: root.host.rail.deal(modelData, initial)
        }
    }
}
