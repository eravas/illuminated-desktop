import QtQuick
import "../../services"
// Devices (outputs), Music, Correspondence, Do Not Disturb: a value on the chin; DND toggles.
CardKind {
    id: adapter
    readonly property string name: card.kind
    detail: name === "media" ? (MediaState.player ? MediaState.player.trackTitle || MediaState.player.identity : "None")
        : name === "notifications" ? NotificationHub.unread + " unread"
        : name === "dnd" ? (NotificationHub.dnd ? "On" : "Off")
        : name === "outputs" ? (AudioState.sink ? AudioState.sink.description || AudioState.sink.name : "—") : ""
    back: name === "outputs" ? outputs : card.genericBack
    Component { id: outputs; OutputsBack { card: adapter.card } }
    function activate() { if (name !== "dnd") return false; NotificationHub.dnd = !NotificationHub.dnd; return true; }
}
