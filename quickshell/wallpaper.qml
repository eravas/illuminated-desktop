import QtQuick
import Quickshell
import Quickshell.Wayland
import "config"
// The desktop wallpaper on every output (background layer), in light and dark mode alike.
// Decoded at the output's size (sourceSize), so a 2560 × 1440 output holds ~15 MB of texture
// and a 1366 × 768 one ~4 MB. Turn off with features.wallpaper = false to keep another tool.
Scope {
    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: win
            required property var modelData
            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            focusable: false
            color: "#1C1A16"
            mask: Region {}
            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.namespace: "illuminated-wallpaper"
            // Cover the output: scale so both sides fill, centre horizontally, place the vertical
            // crop at focusY. (v7 runtime report: a translated PreserveAspectCrop left the bottom bare.)
            Image {
                id: picture
                readonly property real ratio: implicitWidth > 0 ? implicitHeight / implicitWidth : 9 / 16
                readonly property real cover: Math.max(win.width, win.height / ratio)
                width: cover; height: cover * ratio
                x: (win.width - width) / 2
                y: (win.height - height) * Settings.wallpaperFocusY
                source: Settings.wallpaperPath ? "file://" + Settings.wallpaperPath : Qt.resolvedUrl("assets/wallpaper.jpg")
                fillMode: Image.Stretch
                sourceSize.width: Math.round(win.width * (win.screen ? win.screen.devicePixelRatio : 1))
                asynchronous: true
                cache: false
                smooth: true
            }
        }
    }
}
