pragma ComponentBehavior: Bound
import QtQuick
import "../../services"
import "../../config"
import "../CardModel.js" as CardModel
import ".."
// Lock, Sleep, Shut Down, Reboot, Log Out. A card with alternatives turns to a menu (Sleep);
// a confirming card turns to Confirm? (Shut Down, Reboot); otherwise a click acts (Lock).
CardKind {
    id: adapterRoot
    readonly property string name: card.kind
    readonly property string mode: CardModel.sessionMode(card.spec)
    readonly property var entries: mode === "menu" ? [name].concat(card.spec.alternatives) : []
    readonly property bool owned: SessionState.pending === name || entries.indexOf(SessionState.pending) >= 0
    property bool confirming: false
    property bool inlineArmed: false
    presentation: CardModel.power(name, card.colours)
    back: mode === "menu" ? menu : mode === "confirm" ? confirm : null
    Component { id: menu; MenuBack { card: adapterRoot.card; kind: adapterRoot } }
    Component { id: confirm; ConfirmBack { card: adapterRoot.card; kind: adapterRoot } }
    // Runs a session action now; the deck closes once the command has started.
    function act(action) {
        SessionState.select(action);
        if (SessionState.pending !== action) return;
        confirming = true;
        const started = SessionState.confirm();
        confirming = false;
        // Close the deck, and leave this card face up for the next time it opens.
        if (started) { card.flipped = false; Navigation.dismiss(); }
    }
    // Shut Down / Reboot back: a click confirms once the arming delay has passed.
    function confirmFromBack() { if (card.armed && SessionState.pending === name) act(name); }
    // Menu entries (Sleep's back): act at once, or confirm inline ("Log out?") when the entry asks.
    function choose(entry) {
        if (Settings.card(entry).confirm === false) { act(entry); return; }
        if (SessionState.pending === entry && inlineArmed) { act(entry); return; }
        SessionState.select(entry);
        inlineArmed = false;
        inlineArm.restart();
    }
    function entryText(entry) {
        const t = Settings.card(entry).title || entry;
        return SessionState.pending === entry && Settings.card(entry).confirm !== false ? CardModel.sentence(t) + "?" : t;
    }
    Timer { id: inlineArm; interval: Settings.confirmArmDelay; onTriggered: adapterRoot.inlineArmed = true }
    function activate() { if (mode !== "act") return false; act(name); return true; }
    function flipped(isFlipped) {
        if (mode === "confirm") { if (isFlipped) SessionState.select(name); else if (owned) SessionState.cancel(); }
        else if (!isFlipped && owned) SessionState.cancel();
    }
    // A confirmation never outlives the card's focus: selecting another card turns it back.
    function deselected() { if (card.flipped) card.flipped = false; }
    function release() { if (owned) SessionState.cancel(); }
    Connections {
        target: SessionState
        // Expired, cancelled or replaced by another card's confirmation: turn back (cancel).
        function onPendingChanged() {
            if (adapterRoot.mode === "confirm" && adapterRoot.card.flipped && SessionState.pending !== adapterRoot.name && !adapterRoot.confirming && SessionState.error === "")
                adapterRoot.card.flipped = false;
        }
    }
}
