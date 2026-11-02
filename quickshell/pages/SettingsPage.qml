pragma ComponentBehavior: Bound
import QtQuick
import "../theme"
import QtQuick.Layouts
import Quickshell.Services.UPower
import "../components"
import "../config"
ColumnLayout {
    spacing: Theme.gap
    InkLabel { text: "The Herbarium"; variant: "heading" }
    InkLabel { text: (Settings.uiPath ? "Choices here are saved to " + Settings.uiPath + ". " : "Choices here are not saved (read-only session). ") + "Anything set in " + (Settings.source || "config.toml") + " takes precedence; edit it with `illuminated edit`."; Layout.fillWidth: true; wrapMode: Text.Wrap }
    InkLabel { visible: Settings.notice !== "" || Settings.error !== ""; text: Settings.notice || Settings.error; color: Theme.urgent; Layout.fillWidth: true; wrapMode: Text.Wrap }
    Repeater {
        model: Settings.diagnostics
        InkLabel { required property var modelData; text: modelData.level + " · " + modelData.key + (modelData.line ? " (line " + modelData.line + ")" : "") + ": " + modelData.message; variant: "small"; color: modelData.level === "error" ? Theme.urgent : Theme.mutedInk; Layout.fillWidth: true; wrapMode: Text.Wrap }
    }
    component Choice: Flow {
        id: choice
        required property string key
        required property var values
        property var labels: values
        property string current: Settings.option(key, "")
        Layout.fillWidth: true
        spacing: Theme.gap
        Repeater {
            model: choice.values
            ActionButton {
                required property var modelData
                required property int index
                text: (choice.current === String(modelData) ? "● " : "") + choice.labels[index]
                onClicked: Settings.update(choice.key, modelData)
            }
        }
    }
    InkLabel { text: "Vellum"; font.bold: true }
    Choice { key: "appearance.mode"; values: ["dark", "light"]; labels: ["Dark", "Light"] }
    InkLabel { text: "Reading" + (Settings.readingCustom ? " · Custom (based on " + Settings.readingPreset + ")" : ""); font.bold: true }
    Choice { key: "reading.preset"; values: ["default", "legibility", "accessibility"]; labels: ["Default", "Legibility", "Accessibility"] }
    ActionButton {
        visible: Settings.readingCustom
        text: "Reset options to the preset"
        onClicked: Object.keys(Settings.readingOptions).forEach(k => Settings.update("reading.options." + k, "preset"))
    }
    InkLabel { text: "Colour vision"; font.bold: true }
    Choice { key: "appearance.colourVision"; values: ["typical", "protan", "deutan", "tritan"]; labels: ["Typical", "Protan", "Deutan", "Tritan"] }
    InkLabel { text: "Accent wash"; font.bold: true }
    Choice { key: "appearance.wash"; values: ["strong", "medium", "soft"]; labels: ["Strong", "Medium", "Soft"] }
    InkLabel { text: "Logical pixel (dither grain)"; font.bold: true }
    Choice { key: "pixel.logical"; values: [1, 2, 3]; labels: ["1 px", "2 px", "3 px"] }
    InkLabel { text: "Dock"; font.bold: true }
    Choice { key: "dock.mode"; values: ["auto", "permanent", "autohide"]; labels: ["Automatic", "Permanent", "Auto-hide"] }
    InkLabel { text: "Removable media size"; font.bold: true }
    Choice { key: "media.scale"; values: ["auto", "24", "15.6", "27", "14q", "14f", "compact"]; labels: ["Life size", "24″ 1080p", "15.6″ 1080p", "27″ 1440p", "14″ 1440p", "14″ 1080p", "Compact"] }
    ActionButton { text: Settings.reducedMotion ? "Enable motion" : "Reduce motion"; onClicked: Settings.update("motion.reduced", !Settings.reducedMotion) }
    ActionButton { text: Settings.deckAligned ? "Tilt cards" : "Align cards to grid"; onClicked: Settings.update("reading.options.rotation", Settings.deckAligned ? "full" : "off") }
    InkLabel { text: UPower.displayDevice && UPower.displayDevice.ready && UPower.displayDevice.isPresent ? "Battery " + Math.round(UPower.displayDevice.percentage * 100) + "%" : "Battery unavailable"; Layout.fillWidth: true }
    InkLabel { text: "Applications keep their normal surfaces. The existing wallpaper remains visible. Network authentication, lock configuration and power inhibitors remain owned by the existing system services."; Layout.fillWidth: true }
}
