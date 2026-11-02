import QtQuick
// One question for the prompt sheet (authentication, a Wi-Fi passphrase). Owned by whoever asks
// (the polkit agent, NetworkState); Prompts shows at most one at a time.
QtObject {
    property string kind: ""              // "polkit" | "wifi" | …
    property string title: ""
    property string message: ""
    property string prompt: "Password"    // the field's placeholder
    property bool secret: true            // false: the answer is echoed (e.g. a username)
    property bool responseRequired: true  // false while the back end is working
    property string error: ""
    property string note: ""              // supplementary, not an error
    property var identities: []           // display names; empty or one: no choice shown
    property int identity: 0
    property string actionLabel: "Authenticate"
    signal submitted(string answer)
    signal cancelled()
    signal identityChosen(int index)
}
