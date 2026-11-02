import QtQuick
import Quickshell
import Quickshell.Services.Polkit
import "prompts"
// The authentication agent (features.polkit, off by default). Only one agent can hold the
// session: stop your current one (hyprpolkitagent, polkit-gnome, …) before turning this on, and
// turn this off to go back. If registration fails, `illuminated status` reports it and your
// old agent can simply be started again; nothing here replaces it on disk.
Scope {
    id: root
    readonly property bool registered: agent.isRegistered
    readonly property var flow: agent.flow
    PolkitAgent { id: agent }
    // (3) Identity objects are not documented beyond "users or groups"; show whichever name
    // field exists.
    function identityName(identity) {
        if (!identity) return "";
        return String(identity.displayName || identity.name || identity.userName || identity);
    }
    PromptRequest {
        id: request
        kind: "polkit"
        title: "Authentication"
        message: root.flow ? root.flow.message : ""
        prompt: root.flow && root.flow.inputPrompt ? root.flow.inputPrompt.replace(/:\s*$/, "") : "Password"
        secret: !(root.flow && root.flow.responseVisible)
        responseRequired: !!root.flow && root.flow.isResponseRequired
        error: root.flow && root.flow.supplementaryIsError ? root.flow.supplementaryMessage : root.flow && root.flow.failed && root.flow.isResponseRequired ? "That was not accepted. Try again." : ""
        note: root.flow && !root.flow.supplementaryIsError ? root.flow.supplementaryMessage : ""
        identities: root.flow ? Array.from(root.flow.identities).map(i => root.identityName(i)) : []
        identity: root.flow ? Math.max(0, Array.from(root.flow.identities).indexOf(root.flow.selectedIdentity)) : 0
        onSubmitted: answer => { if (root.flow) root.flow.submit(answer); }
        onCancelled: { if (root.flow && !root.flow.isCompleted) root.flow.cancelAuthenticationRequest(); Prompts.close(request); }
        onIdentityChosen: index => { if (root.flow) root.flow.selectedIdentity = Array.from(root.flow.identities)[index]; }
    }
    // Show while a flow is active; close when it completes (success or cancel).
    readonly property bool asking: agent.isActive && !!flow && !flow.isCompleted
    onAskingChanged: if (asking) Prompts.show(request); else Prompts.close(request)
}
