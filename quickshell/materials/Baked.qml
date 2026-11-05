pragma Singleton
import QtQuick
import Quickshell
// Images painted once at runtime and shared (vellum edges, focus halos): key → data URL. The
// first item that needs a key claims it and paints it (in its own small canvas); every item with
// the same key then shows the same image. Reactive: items bind to `urls[key]`.
Singleton {
    id: root
    property var urls: ({})
    property var claimed: ({})
    function claim(key) { if (urls[key] || claimed[key]) return false; const c = Object.assign({}, claimed); c[key] = true; claimed = c; return true; }
    function put(key, url) { const u = Object.assign({}, urls); u[key] = url; urls = u; }
    function release(key) { const c = Object.assign({}, claimed); delete c[key]; claimed = c; }
}
