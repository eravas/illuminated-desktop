// Pure policy, shared by QML and the Node tests. No process or compositor access.
function ordinaryWorkspaces(workspaces, monitorName, allMonitors) {
    if (!monitorName)
        return [];

    return workspaces.filter(function(workspace) {
        // Named ordinary workspaces also have negative IDs. Filter by name,
        // never by ID sign, to retain those while excluding scratchpads.
        if (!workspace || workspace.name === "special"
                || String(workspace.name).indexOf("special:") === 0)
            return false;
        return allMonitors || (workspace.monitor
            && workspace.monitor.name === monitorName);
    }).sort(function(a, b) { return a.id - b.id; });
}

function workspaceLabel(workspace) {
    if (!workspace)
        return "";
    return String(workspace.name || workspace.id);
}
