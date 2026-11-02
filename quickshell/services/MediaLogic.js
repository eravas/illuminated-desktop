// Removable media: udisks2 object tree → device objects for the rail (SURFACES.md §2a).
// Pure; shared by RemovableMedia.qml and tests/media-logic.test.cjs.
//
// Input is `busctl --system --json=short call org.freedesktop.UDisks2 /org/freedesktop/UDisks2
// org.freedesktop.DBus.ObjectManager GetManagedObjects`: {"type": "a{oa{sa{sv}}}", "data": [{…}]},
// variants as {"type", "data"}, byte strings ("ay", "aay") as arrays of numbers. (3) The exact
// busctl JSON shape is assumed from systemd's documentation; the parser accepts either a
// {"type","data"} wrapper or plain values at every level.

var DRIVE = "org.freedesktop.UDisks2.Drive", BLOCK = "org.freedesktop.UDisks2.Block", FS = "org.freedesktop.UDisks2.Filesystem";
var ENCRYPTED = "org.freedesktop.UDisks2.Encrypted", LOOP = "org.freedesktop.UDisks2.Loop", PARTITION = "org.freedesktop.UDisks2.Partition";

function unwrap(v) {
    while (v && typeof v === "object" && !Array.isArray(v) && Object.prototype.hasOwnProperty.call(v, "type") && Object.prototype.hasOwnProperty.call(v, "data")) v = v.data;
    return v;
}
// NUL-terminated byte string (paths, mount points) → JS string (UTF-8).
function bytes(v) {
    v = unwrap(v);
    if (typeof v === "string") return v.replace(/\0+$/, "");
    if (!Array.isArray(v)) return "";
    var s = "";
    for (var i = 0; i < v.length && v[i] !== 0; i++) s += String.fromCharCode(v[i]);
    try { return decodeURIComponent(escape(s)); } catch (e) { return s; }
}
function strings(v) { v = unwrap(v); return Array.isArray(v) ? v.map(bytes).filter(function (s) { return s; }) : []; }

// → {path: {interface: {property: plain value}}}
function parseManagedObjects(text) {
    var root = typeof text === "string" ? JSON.parse(text) : text, data = unwrap(root);
    if (Array.isArray(data)) data = data[0];
    data = unwrap(data);
    var out = {};
    for (var path in data) {
        var ifaces = unwrap(data[path]), o = {};
        for (var name in ifaces) {
            var props = unwrap(ifaces[name]), p = {};
            for (var k in props) p[k] = unwrap(props[k]);
            o[name] = p;
        }
        out[path] = o;
    }
    return out;
}

// Art for a drive, in the order of SURFACES.md §2a; an exact VID:PID override wins.
function classify(drive, block, udev, overrides) {
    var u = udev || {}, vid = String(u.ID_VENDOR_ID || "").toLowerCase(), pid = String(u.ID_MODEL_ID || "").toLowerCase();
    var key = vid && pid ? vid + ":" + pid : "";
    if (key && overrides && overrides[key]) return overrides[key];
    var d = drive || {}, b = block || {}, compat = (unwrap(d.MediaCompatibility) || []).map(String), media = String(d.Media || "");
    var any = function (re) { return re.test(media) || compat.some(function (c) { return re.test(c); }); };
    var label = String(b.IdLabel || "");
    if (any(/^optical/)) return "disc";
    if (any(/^floppy_zip/)) return "zip";
    if (any(/^floppy/)) return "floppy";
    if (any(/^flash_(sd|mmc)/) || d.ConnectionBus === "sdio") return "sd";
    if (any(/^thumb$/)) return "usb";
    if (vid === "2e8a" || /^(RPI-RP2|RP2350)$/i.test(label)) return "pico";
    if (/BOOT$/i.test(label) && b.IdType === "vfat") return "esp32";
    if (vid === "2237" || vid === "1949") return "ereader";
    var rate = Number(d.RotationRate);
    if (rate > 0 || rate === -1) return "drive";
    if (any(/^flash_cf/)) return "cf";
    if (any(/^flash_ms/)) return "ms";
    return "ssd";
}

function removableDrive(d) {
    return !!(d && (d.Removable || d.MediaRemovable || d.Ejectable || ["usb", "sdio", "ieee1394"].indexOf(d.ConnectionBus) >= 0));
}

// Devices to show, in udisks order. udev: {drivePath: {ID_VENDOR_ID, …}}; overrides: {"vvvv:pppp": kind}.
function devices(objects, udev, overrides) {
    var blocks = [], drives = {}, path;
    for (path in objects) {
        if (objects[path][DRIVE]) drives[path] = objects[path][DRIVE];
        if (objects[path][BLOCK]) blocks.push({path: path, ifaces: objects[path]});
    }
    var cleartext = {};   // crypto container path → unlocked block entry
    blocks.forEach(function (e) { var back = String(e.ifaces[BLOCK].CryptoBackingDevice || "/"); if (back !== "/") cleartext[back] = e; });
    var out = [];
    function entry(id, drive, primary, kind) {
        var b = primary.ifaces[BLOCK], encrypted = !!primary.ifaces[ENCRYPTED] || b.IdUsage === "crypto";
        var open = encrypted ? cleartext[primary.path] : primary, fsb = open && open.ifaces[FS] ? open : null;
        var mounts = fsb ? strings(fsb.ifaces[FS].MountPoints) : [];
        var fsBlock = fsb ? fsb.ifaces[BLOCK] : b;
        return {id: id, kind: kind, drivePath: id, blockPath: primary.path, device: bytes(b.PreferredDevice || b.Device),
                fsPath: fsb ? fsb.path : "", fsDevice: fsb ? bytes(fsBlock.PreferredDevice || fsBlock.Device) : "",
                label: String(fsBlock.IdLabel || (drive && (drive.Model || drive.Vendor)) || "Disk").trim() || "Disk",
                fsType: String(fsBlock.IdType || ""), size: Number(fsBlock.Size || b.Size || 0),
                encrypted: encrypted, locked: encrypted && !open, mounted: mounts.length > 0, mountPoint: mounts[0] || "",
                ejectable: !!(drive && drive.Ejectable), canPowerOff: !!(drive && drive.CanPowerOff), optical: kind === "disc" && !!drive,
                vendor: drive ? String(drive.Vendor || "") : "", model: drive ? String(drive.Model || "") : "", bus: drive ? String(drive.ConnectionBus || "") : ""};
    }
    for (path in drives) {
        var d = drives[path];
        if (!removableDrive(d)) continue;
        var own = blocks.filter(function (e) { var b = e.ifaces[BLOCK]; return b.Drive === path && !b.HintIgnore && !b.HintSystem && String(b.CryptoBackingDevice || "/") === "/"; });
        if (!own.length) continue;
        var compat = (unwrap(d.MediaCompatibility) || []).map(String);
        if ((compat.some(function (c) { return /^optical/.test(c); }) || /^optical/.test(String(d.Media || ""))) && !d.MediaAvailable) continue;   // empty optical drive: invisible
        var candidates = own.filter(function (e) { return e.ifaces[FS] || e.ifaces[ENCRYPTED] || e.ifaces[BLOCK].IdUsage === "crypto"; });
        if (!candidates.length) continue;
        candidates.sort(function (a, b) { return Number(b.ifaces[BLOCK].Size || 0) - Number(a.ifaces[BLOCK].Size || 0); });
        var primary = candidates[0], whole = own.filter(function (e) { return !e.ifaces[PARTITION]; })[0] || primary;
        var dev = entry(path, d, primary, classify(d, primary.ifaces[BLOCK], udev ? udev[path] : null, overrides));
        dev.disk = bytes(whole.ifaces[BLOCK].PreferredDevice || whole.ifaces[BLOCK].Device);
        out.push(dev);
    }
    // Disk images (loop devices) carrying an optical filesystem use the disc art.
    blocks.forEach(function (e) {
        var b = e.ifaces[BLOCK];
        if (!e.ifaces[LOOP] || b.HintIgnore || b.HintSystem || ["iso9660", "udf"].indexOf(b.IdType) < 0) return;
        out.push(entry(e.path, null, e, "disc"));
    });
    return out;
}

// `udevadm info --query=property` / --export-db blocks / monitor events → property maps.
function parseUdev(text) {
    var out = [], cur = null;
    String(text).split("\n").forEach(function (line) {
        line = line.replace(/\r$/, "");
        if (!line.trim()) { if (cur && Object.keys(cur).length) out.push(cur); cur = null; return; }
        if (!cur) cur = {};
        var m = /^(?:E: )?([A-Z0-9_]+)=(.*)$/.exec(line);
        if (m) cur[m[1]] = m[2];
        else if (/^(?:UDEV|KERNEL)\s+\[[^\]]*\]\s+(\w+)\s+(\S+)/.test(line)) { var e = /^(?:UDEV|KERNEL)\s+\[[^\]]*\]\s+(\w+)\s+(\S+)/.exec(line); cur.ACTION = cur.ACTION || e[1]; cur.DEVPATH = cur.DEVPATH || e[2]; }
        else if (/^P: /.test(line)) cur.DEVPATH = line.slice(3);
    });
    if (cur && Object.keys(cur).length) out.push(cur);
    return out;
}
// Phones are not udisks devices: Android via libmtp's ID_MTP_DEVICE, iPhone via Apple's
// vendor ID (usbmuxd). Cameras (PTP) are skipped for now; other MTP devices use the Android art.
function phone(props) {
    if (!props || props.DEVTYPE !== "usb_device") return null;
    var vid = String(props.ID_VENDOR_ID || "").toLowerCase(), model = String(props.ID_MODEL || props.ID_MODEL_FROM_DATABASE || "").replace(/_/g, " ");
    if (vid === "05ac" && /iphone|ipad/i.test(model + " " + (props.ID_MODEL_FROM_DATABASE || ""))) return {kind: "iphone", serial: String(props.ID_SERIAL_SHORT || "")};
    if (props.ID_MTP_DEVICE === "1" && props.ID_GPHOTO2 !== "1" && !/camera/i.test(model)) return {kind: "android", serial: String(props.ID_SERIAL || props.ID_SERIAL_SHORT || "")};
    return null;
}
function phoneDevice(props) {
    var p = phone(props); if (!p) return null;
    var label = String(props.ID_MODEL_FROM_DATABASE || props.ID_MODEL || "Phone").replace(/_/g, " ");
    return {id: "usb:" + props.DEVPATH, kind: p.kind, phone: true, label: label, serial: p.serial, mounted: false, locked: false, encrypted: false,
            size: 0, mountPoint: "", uri: p.kind === "iphone" ? "afc://" + p.serial + "/" : "mtp://" + String(props.ID_SERIAL || "").replace(/[^A-Za-z0-9_.-]/g, "") + "/"};
}

// "used size" from `df -B1 --output=used,size <mountpoint>` → {used, size} (bytes), or null.
function parseDf(text) {
    var lines = String(text).trim().split("\n");
    if (lines.length < 2) return null;
    var f = lines[lines.length - 1].trim().split(/\s+/).map(Number);
    return f.length >= 2 && f[1] > 0 ? {used: f[0], size: f[1]} : null;
}
