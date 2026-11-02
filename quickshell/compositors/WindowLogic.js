// Dock window model and Hyprland dispatch strings. Pure; shared by the adapters and the
// Node tests. DESIGN.md §6 (top dock).

// Hyprland addresses arrive with or without 0x depending on the source (IPC JSON vs events).
function address(value) {
    var s = String(value || "").trim();
    if (!s) return "";
    if (!/^0x/i.test(s)) s = "0x" + s;
    return /^0x[0-9a-fA-F]+$/.test(s) ? s.toLowerCase() : "";
}
function safeWorkspace(name) { return /^[A-Za-z0-9:_-]+$/.test(String(name)) ? String(name) : ""; }
// Fill a dispatch template; "" when an argument would not be safe to send.
function fill(template, vars) {
    var ok = true;
    var out = String(template).replace(/\{(\w+)\}/g, function (_, k) {
        var v = k === "address" ? address(vars[k]) : k === "workspace" ? safeWorkspace(vars[k]) : "";
        if (!v) ok = false;
        return v;
    });
    return ok ? out : "";
}
function dispatchFor(kind, lua, templates, vars) {
    var t = templates || {};
    var key = (lua ? "lua" : "legacy") + (kind === "focus" ? "Focus" : "Move");
    return t[key] ? fill(t[key], vars) : "";
}
// One dock entry per window. minimizeWorkspace: name of the special workspace used as the
// minimised state ("minimized" → "special:minimized"). Other special workspaces (scratchpads)
// are not shown. Order is the compositor's list order, which is opening order (3).
function hyprlandWindows(toplevels, activeAddress, minimizeWorkspace) {
    var minimized = "special:" + (minimizeWorkspace || "minimized"), out = [], active = address(activeAddress);
    for (var i = 0; i < toplevels.length; i++) {
        var t = toplevels[i]; if (!t) continue;
        var ipc = t.lastIpcObject || {}, ws = t.workspace || null;
        var wsName = ws ? String(ws.name) : ipc.workspace ? String(ipc.workspace.name) : "";
        var wsId = ws ? ws.id : ipc.workspace ? ipc.workspace.id : 0;
        var isMin = wsName === minimized, special = wsName.indexOf("special") === 0;
        if (special && !isMin) continue;
        var addr = address(t.address || ipc.address);
        if (!addr) continue;
        out.push({id: addr, title: String(t.title || ipc.title || ""), appId: String((t.wayland && t.wayland.appId) || ipc.class || ipc.initialClass || ""),
                  workspace: isMin ? 0 : wsId, workspaceName: isMin ? "" : wsName, minimized: isMin, focused: addr === active});
    }
    return out;
}
function mangoWindows(clients) {
    var out = [];
    for (var i = 0; i < clients.length; i++) {
        var c = clients[i]; if (!c || c.is_scratchpad || c.is_namedscratchpad) continue;
        var tags = Array.isArray(c.tags) ? c.tags : [];
        out.push({id: String(c.id), title: String(c.title || ""), appId: String(c.appid || c.app_id || c.class || ""),
                  workspace: tags.length ? tags[0] : 0, workspaceName: tags.length ? String(tags[0]) : "", minimized: !!c.is_minimized,
                  focused: !!c.is_focused, output: c.monitor || ""});
    }
    return out;
}
