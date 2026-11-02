pragma Singleton
import QtQuick
import Quickshell.Services.Mpris
QtObject {
    readonly property var players: Mpris.players.values
    property string preferred: ""
    readonly property var player: players.find(p => p.dbusName === preferred) || players.find(p => p.isPlaying) || players[0] || null
    function toggle() { if (player && player.canTogglePlaying) player.togglePlaying(); }
    function next() { if (player && player.canGoNext) player.next(); }
    function previous() { if (player && player.canGoPrevious) player.previous(); }
}
