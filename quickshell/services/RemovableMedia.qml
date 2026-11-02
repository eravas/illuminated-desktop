pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import "../config"
import "MediaLogic.js" as Logic
// Removable media from udisks2 and udev (SURFACES.md §2a). Quickshell has no udisks module,
// so this follows events, not a timer: `udisksctl monitor` and `udevadm monitor` stream
// changes; each burst triggers one `busctl … GetManagedObjects` snapshot (JSON). Actions go
// through udisksctl / udisks D-Bus under the user's polkit session; nothing is automounted
// and nothing is ever run from a device. Passphrases go to udisksctl on stdin only.
Singleton {
    id: root
    property var drives: []           // from udisks
    property var phones: []           // from udev
    readonly property var devices: drives.concat(phones)
    property var udev: ({})           // drive path → udev properties (vendor/model IDs)
    property var engaged: ({})        // phone id → true once opened (its "mounted" pose)
    property var usage: ({})          // id → {used, size}
    property var busy: ({})           // id → action name while one runs
    property var errors: ({})         // id → last failure, in words
    property string error: ""         // service-level problem (udisks missing, …)
    readonly property bool enabled: Settings.enableMedia
    signal ejected(string id)
    property string warning: ""
    property var ejectedIds: ({})
    onEjected: function(id) { ejectedIds = mark(ejectedIds, id, true); }
    signal unlocked(string id)

    function find(id) { return devices.find(d => d.id === id) || null; }
    function mark(map, id, value) { const o = Object.assign({}, map); if (value === undefined || value === "") delete o[id]; else o[id] = value; return o; }
    function setBusy(id, action) { busy = mark(busy, id, action); }
    function fail(id, message) { errors = mark(errors, id, message); }

    // ── Snapshots ─────────────────────────────────────────────────────────
    function refresh() { if (enabled && !snapshot.running) snapshot.running = true; else if (enabled) again = true; }
    property bool again: false
    Timer { id: debounce; interval: 150; onTriggered: root.refresh() }
    Process {
        id: snapshot
        command: ["busctl", "--system", "--json=short", "call", "org.freedesktop.UDisks2", "/org/freedesktop/UDisks2", "org.freedesktop.DBus.ObjectManager", "GetManagedObjects"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const objects = Logic.parseManagedObjects(this.text);
                    const list = Logic.devices(objects, root.udev, Settings.mediaOverrides);
                    // A mounted device that vanished without Eject: drop it at once and say so.
                    const gone = root.drives.filter(o => o.mounted && !list.some(d => d.id === o.id) && !root.ejectedIds[o.id]);
                    if (gone.length) root.warning = gone[0].label + " was removed without ejecting";
                    root.drives = list; root.error = "";
                    list.forEach(d => { if (d.disk && !root.udev[d.drivePath]) udevQuery.ask(d.drivePath, d.disk); if (d.mounted && !root.usage[d.id]) root.measure(d.id); });
                } catch (e) { root.error = "Could not read udisks2 (" + e + ")"; }
            }
        }
        stderr: StdioCollector { onStreamFinished: if (this.text.trim()) root.error = this.text.trim().split("\n")[0] }
        onExited: if (root.again) { root.again = false; Qt.callLater(root.refresh); }
    }
    // Change stream (no polling). Restarted if it exits; a missing udisks2 reports once.
    Process {
        id: watch
        running: root.enabled
        command: ["udisksctl", "monitor"]
        stdout: SplitParser { onRead: debounce.restart() }
        onStarted: root.refresh()
        onExited: function(code) { if (code === 127) root.error = "udisks2 (udisksctl) is not installed"; else if (root.enabled) restart.start(); }
    }
    Timer { id: restart; interval: 3000; onTriggered: watch.running = true }

    // udev properties for a drive's whole disk (VID:PID for overrides and art), once per drive.
    QtObject {
        id: udevQuery
        property var queue: []
        function ask(path, dev) { if (queue.some(q => q.path === path)) return; queue = queue.concat([{path: path, dev: dev}]); next(); }
        function next() { if (udevInfo.running || !queue.length) return; udevInfo.target = queue[0]; queue = queue.slice(1); udevInfo.command = ["udevadm", "info", "--query=property", "--name=" + udevInfo.target.dev]; udevInfo.running = true; }
    }
    Process {
        id: udevInfo
        property var target: null
        stdout: StdioCollector {
            onStreamFinished: {
                const props = Logic.parseUdev(this.text)[0] || {};
                root.udev = Object.assign({}, root.udev, {[udevInfo.target.path]: props});
                root.refresh();   // art may change with the VID:PID
            }
        }
        onExited: Qt.callLater(udevQuery.next)
    }
    // Phones (MTP, iPhone): a one-off enumeration, then udev's USB event stream.
    Process {
        id: enumerate
        running: root.enabled
        command: ["udevadm", "info", "--export-db"]
        stdout: StdioCollector { onStreamFinished: root.phones = Logic.parseUdev(this.text).map(Logic.phoneDevice).filter(p => p) }
    }
    Process {
        id: usbWatch
        running: root.enabled
        command: ["udevadm", "monitor", "--udev", "--property", "--subsystem-match=usb"]
        property var lines: []
        stdout: SplitParser {
            onRead: function(line) {
                if (line.trim()) { usbWatch.lines.push(line); return; }
                const event = Logic.parseUdev(usbWatch.lines.join("\n"))[0]; usbWatch.lines = [];
                if (!event || !event.DEVPATH) return;
                const id = "usb:" + event.DEVPATH;
                if (event.ACTION === "remove") { if (root.phones.some(p => p.id === id)) { root.phones = root.phones.filter(p => p.id !== id); root.engaged = root.mark(root.engaged, id, undefined); } }
                else if (event.ACTION === "add") { const p = Logic.phoneDevice(event); if (p && !root.phones.some(q => q.id === id)) root.phones = [p].concat(root.phones); }
            }
        }
    }

    // ── Actions ───────────────────────────────────────────────────────────
    component Job: Process {
        id: job
        property string device: ""
        property string action: ""
        property string input: ""
        property var done: null
        property string out: ""
        stdinEnabled: input !== ""
        onStarted: if (input !== "") { write(input); stdinEnabled = false; }
        stdout: StdioCollector { onStreamFinished: job.out = this.text }
        stderr: StdioCollector { id: errText }
        // Collectors may finish just after exit; settle on the next turn of the event loop.
        onExited: function(code) { Qt.callLater(function() { job.finish(code); }); }
        function finish(code) {
            const device = job.device, action = job.action, out = job.out, done = job.done;
            root.setBusy(device, "");
            if (device) {
                if (code !== 0) root.fail(device, (errText.text || "").trim().split("\n").pop().replace(/^Error [^:]*: /, "") || action + " failed (" + code + ")");
                else root.fail(device, "");
            }
            if (done) done(code, out);
            if (device) root.refresh();
            job.destroy();
        }
    }
    Component { id: jobComponent; Job {} }
    function run(id, action, argv, input, done) {
        if (busy[id]) return false;
        setBusy(id, action);
        const job = jobComponent.createObject(root, {device: id, action: action, input: input || "", done: done || null, command: argv});
        job.running = true;
        return true;
    }
    function measure(id) {
        const d = find(id); if (!d || !d.mountPoint) return;
        const job = jobComponent.createObject(root, {device: "", action: "df", command: ["df", "-B1", "--output=used,size", d.mountPoint],
            done: function(code, out) { const u = Logic.parseDf(out); if (u) root.usage = root.mark(root.usage, id, u); }});
        job.running = true;
    }
    // First click: mount (or, for a phone, open it in the file manager).
    function mount(id) {
        const d = find(id); if (!d) return;
        if (d.phone) { engaged = mark(engaged, id, true); open(id); return; }
        if (d.locked || d.mounted || !d.fsDevice) return;
        run(id, "mount", ["udisksctl", "mount", "-b", d.fsDevice], "", code => { if (code === 0) Qt.callLater(() => root.measure(id)); });
    }
    function unlock(id, passphrase) {
        const d = find(id); if (!d || !d.locked) return;
        // --key-file /dev/stdin: the passphrase is never an argument; no trailing newline.
        run(id, "unlock", ["udisksctl", "unlock", "-b", d.device, "--key-file", "/dev/stdin"], passphrase, code => { if (code === 0) { root.unlocked(id); Qt.callLater(() => root.mount(id)); } });
    }
    function open(id) {
        const d = find(id); if (!d) return;
        const target = d.phone ? d.uri : d.mountPoint;
        if (target) Quickshell.execDetached(["xdg-open", target]);
    }
    // Eject: unmount, lock an unlocked LUKS volume, then power the drive off (or eject a disc).
    function eject(id) {
        const d = find(id); if (!d) return;
        if (d.phone) { engaged = mark(engaged, id, undefined); ejected(id); return; }
        const last = () => {
            if (d.optical && d.ejectable) run(id, "eject", ["busctl", "--system", "call", "org.freedesktop.UDisks2", d.drivePath, "org.freedesktop.UDisks2.Drive", "Eject", "a{sv}", "0"], "", c => { if (c === 0) root.ejected(id); });
            else if (d.canPowerOff && d.disk) run(id, "eject", ["udisksctl", "power-off", "-b", d.disk], "", c => { if (c === 0) root.ejected(id); });
            else root.ejected(id);
        };
        const lock = () => { if (d.encrypted && !d.locked) run(id, "lock", ["udisksctl", "lock", "-b", d.device], "", c => { if (c === 0) Qt.callLater(last); }); else last(); };
        if (d.mounted) run(id, "unmount", ["udisksctl", "unmount", "-b", d.fsDevice], "", c => { if (c === 0) Qt.callLater(lock); });
        else lock();
    }
    function rename(id, label) {
        const d = find(id); if (!d || !d.fsPath || !label) return;
        run(id, "rename", ["busctl", "--system", "call", "org.freedesktop.UDisks2", d.fsPath, "org.freedesktop.UDisks2.Filesystem", "SetLabel", "sa{sv}", label, "0"]);
    }
    // Format keeps the current filesystem type and label (exFAT when there is none). Unmounts first.
    function format(id) {
        const d = find(id); if (!d || d.locked || !d.fsPath) return;
        const type = ["vfat", "exfat", "ext4", "ntfs", "btrfs", "f2fs", "xfs"].indexOf(d.fsType) >= 0 ? d.fsType : "exfat";
        const go = () => run(id, "format", ["busctl", "--system", "--timeout=600", "call", "org.freedesktop.UDisks2", d.fsPath, "org.freedesktop.UDisks2.Block", "Format", "sa{sv}", type, "1", "label", "s", d.label]);
        if (d.mounted) run(id, "unmount", ["udisksctl", "unmount", "-b", d.fsDevice], "", c => { if (c === 0) Qt.callLater(go); });
        else go();
    }
}
