pragma Singleton
import QtQuick
// The one prompt on screen. A newer request replaces an older one, which is cancelled; the
// authentication agent's requests take precedence over anything else.
QtObject {
    id: root
    property QtObject current: null
    function show(request) {
        if (!request || current === request) return;
        if (current && current.kind === "polkit" && request.kind !== "polkit") { request.cancelled(); return; }
        const previous = current;
        current = request;
        if (previous) previous.cancelled();
    }
    function close(request) { if (!request || current === request) current = null; }
}
