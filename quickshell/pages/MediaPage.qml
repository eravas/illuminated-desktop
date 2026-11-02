pragma ComponentBehavior: Bound
import QtQuick
import "../theme"
import QtQuick.Controls
import QtQuick.Layouts
import "../components"
import "../services"
ColumnLayout {
    spacing: Theme.gap
    InkLabel { text: "Music and media"; variant: "heading" }
    Repeater { model: MediaState.players; ActionButton { required property var modelData; text: (modelData === MediaState.player ? "✓ " : "") + modelData.identity; onClicked: MediaState.preferred = modelData.dbusName } }
    InkLabel { text: MediaState.player ? (MediaState.player.trackTitle || "Untitled") + "\n" + MediaState.player.trackArtist : "No MPRIS player. MPD needs the official mpd-mpris bridge; rmpc itself is not assumed to expose MPRIS."; Layout.fillWidth: true }
    RowLayout {
        ActionButton { text: "Previous"; enabled: MediaState.player && MediaState.player.canGoPrevious; onClicked: MediaState.previous() }
        ActionButton { text: MediaState.player && MediaState.player.isPlaying ? "Pause" : "Play"; enabled: MediaState.player && MediaState.player.canTogglePlaying; onClicked: MediaState.toggle() }
        ActionButton { text: "Next"; enabled: MediaState.player && MediaState.player.canGoNext; onClicked: MediaState.next() }
    }
    LevelSlider { Layout.fillWidth: true; from: 0; to: MediaState.player && MediaState.player.lengthSupported ? MediaState.player.length : 1; value: MediaState.player && MediaState.player.positionSupported ? MediaState.player.position : 0; enabled: MediaState.player && MediaState.player.canSeek && MediaState.player.lengthSupported; onMoved: if (MediaState.player) MediaState.player.position = value }
}
