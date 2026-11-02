import QtQuick
import Quickshell
import Quickshell.Io
import "greeter"
ShellRoot {
    Greeter { id: login }
    function find(node, name) { if (node.objectName === name) return node; for (const child of node.children || []) { const found = find(child, name); if (found) return found; } return null; }
    IpcHandler {
        target: "test"
        function state(): string { const field=find(login.contentItem,"greeter-response");return JSON.stringify({progress:login.progress,authenticated:login.authenticated,launchSent:login.launchSent,sessions:login.sessions.length,prompt:login.responseRequired,message:login.message,secretLength:field ? field.length : -1}); }
        function cancel(): void { login.cancel(); }
        function stall(): void { login.progress = 1; } // explicit animation-failure fixture
        function skip(): void { login.bypassMotion(); }
    }
}
