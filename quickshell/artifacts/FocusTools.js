// Focus a usable control inside a face/sheet, without entering hidden faces.
function first(node) {
    if (!node || !node.visible || !node.enabled) return false;
    if (node.activeFocusOnTab) { node.forceActiveFocus(Qt.TabFocusReason); return true; }
    for (const child of node.children || []) if (first(child)) return true;
    return false;
}
