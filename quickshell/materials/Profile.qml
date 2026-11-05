pragma Singleton
import QtQuick
import Quickshell
// Opt-in paint timing for the before/after numbers in docs/STATUS.md (Phase 5).
// ILLUMINATED_PROFILE=1: one line per Canvas paint, plus `alive` (Canvas items that exist).
Singleton {
    readonly property bool enabled: Quickshell.env("ILLUMINATED_PROFILE") === "1"
    property int alive: 0
    onAliveChanged: console.info("illuminated-profile alive " + alive)
    function paint(kind, w, h, ensureMs, paintMs) {
        console.info("illuminated-profile paint " + kind + " " + w + "x" + h + " ensure=" + ensureMs + " paint=" + paintMs);
    }
}
