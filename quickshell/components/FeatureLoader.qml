import QtQuick
Loader {
    // The feature API is intentionally dynamic; Loader.item itself is QObject.
    readonly property var feature: item
}
