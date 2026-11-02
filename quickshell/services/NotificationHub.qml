pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import "../config"
Singleton {
    id: root
    property bool enabled: false
    property bool dnd: false
    property var history: []
    property var live: ({})
    property string storageError: ""
    property bool storageReady: false
    readonly property int unread: history.filter(row => !row.read).length
    readonly property var popups: dnd ? [] : history.filter(row => row.active && row.deadline > now).slice(0, 3)
    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/illuminated"
    function receive(notification, quiet) {
        const previous = history.find(row => row.id === notification.id && row.active);
        const time = Date.now(), critical = notification.urgency === NotificationUrgency.Critical;
        const updated = Object.assign({}, live); updated[notification.id] = notification; live = updated;
        const row = {uid: previous ? previous.uid : time + "-" + notification.id, id: notification.id, app: notification.appName.slice(0, 200), summary: notification.summary.slice(0, 1000),
            body: notification.body.slice(0, 8192), timestamp: time, active: true, read: previous ? previous.read : false,
            urgency: critical ? 2 : notification.urgency === NotificationUrgency.Low ? 0 : 1,
            // Critical slips stay until dismissed (freedesktop spec); others for their timeout.
            deadline: quiet ? 0 : critical ? time + 864e5 * 365 : time + (notification.expireTimeout > 0 ? notification.expireTimeout : 6000)};
        history = [row].concat(history.filter(r => r !== previous)).slice(0, Settings.notificationHistoryLimit);
        save.restart();
    }
    function closed(id) {
        const updated = Object.assign({}, live); delete updated[id]; live = updated;
        history = history.map(r => r.id === id && r.active ? Object.assign({}, r, {active: false}) : r);
        save.restart();
    }
    function dismiss(id) { const notification = live[id]; if (notification) notification.dismiss(); else remove(id); }
    function removeHistory(uid) { history = history.filter(row => row.uid !== uid); save.restart(); }
    function remove(id) { history = history.filter(row => row.id !== id); save.restart(); }
    function clear() { Object.values(live).forEach(n => n.dismiss()); history = []; save.restart(); }
    function markRead() { history = history.map(row => Object.assign({}, row, {read: true})); save.restart(); }
    function invoke(id, index) {
        const notification = live[id];
        if (notification && notification.actions[index]) {
            notification.actions[index].invoke();
        }
    }
    Process {
        id: directory
        command: ["sh", "-c", "umask 077; mkdir -p -m 700 \"$1\" && { [ -e \"$1/notifications.json\" ] || (set -C; printf '%s' '{\"history\":[],\"dnd\":false}' > \"$1/notifications.json\"); }", "illuminated-history", root.stateDir]
        running: true
        onExited: function(code) { if (code === 0) { root.storageReady = true; store.path = root.stateDir + "/notifications.json"; } else root.storageError = "Cannot create notification history directory"; }
    }
    FileView {
        id: store
        blockWrites: true
        atomicWrites: true
        printErrors: false
        onLoadFailed: function(error) { if (error !== FileViewError.FileNotFound) root.storageError = "History read failed: " + FileViewError.toString(error); }
        onSaveFailed: function(error) { root.storageError = "History write failed: " + FileViewError.toString(error); }
        onLoaded: {
            try {
                const state = JSON.parse(text());
                root.dnd = !!state.dnd;
                if (Array.isArray(state.history)) root.history = root.history.concat(state.history.filter(row => !root.live[row.id]).slice(0, Settings.notificationHistoryLimit).map(row => Object.assign({}, row, {active: false, uid: row.uid || row.timestamp + "-" + row.id}))).slice(0, Settings.notificationHistoryLimit);
            } catch (e) { root.storageError = "Unreadable saved notification history"; }
        }
    }
    Timer {
        id: save; interval: 250
        onTriggered: if (root.storageReady) store.setText(JSON.stringify({dnd: root.dnd, history: root.history}));
    }
    onDndChanged: save.restart()
}
