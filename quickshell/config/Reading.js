// Reading presets over independent options (DESIGN-SYSTEM.md §3.9). Pure; shared by
// Settings.qml and the Node tests. Components ask for an option, never a preset name.
//
// Precedence: an option set explicitly (any value but "preset") wins; an option left on
// "preset" takes the chosen preset's value; Legibility starts from Default and Accessibility
// from Legibility, so every preset names every option.

var OPTIONS = {
    face: ["pirata", "germania", "sans"],
    numerals: ["minuscule", "capital", "arabic"],
    typeScale: ["normal", "large"],
    texture: ["full", "reduced", "off"],
    wash: ["fade", "off"],
    edge: ["frayed", "solid"],
    levelMark: ["dither", "line", "solid"],
    art: ["full", "muted"],
    rotation: ["full", "reduced", "off"],
    transitions: ["full", "crossfade"],
    loupeMotion: ["slide", "jump"],
    focus: ["halo", "thick", "solid"],
    loupe: ["magnify", "ring"],
    targets: ["standard", "large"],
    hoverInfo: ["hover", "focus", "always"],
    dockAutoHide: ["allowed", "never"],
    confirmTimeout: ["normal", "long"],
    lowChargeNumeral: ["off", "on"],
    secondaryInk: ["normal", "high"]
};

var DEFAULT = {
    face: "pirata", numerals: "minuscule", typeScale: "normal", texture: "full", wash: "fade",
    edge: "frayed", levelMark: "dither", art: "full", rotation: "full", transitions: "full", loupeMotion: "slide",
    focus: "halo", loupe: "magnify", targets: "standard", hoverInfo: "hover", dockAutoHide: "allowed",
    confirmTimeout: "normal", lowChargeNumeral: "off", secondaryInk: "normal"
};
function extend(base, changes) { var o = {}, k; for (k in base) o[k] = base[k]; for (k in changes) o[k] = changes[k]; return o; }
var LEGIBILITY = extend(DEFAULT, {
    face: "germania", numerals: "capital", texture: "reduced", levelMark: "line", rotation: "reduced",
    focus: "thick", hoverInfo: "focus", lowChargeNumeral: "on", secondaryInk: "high"
});
var ACCESSIBILITY = extend(LEGIBILITY, {
    face: "sans", numerals: "arabic", typeScale: "large", texture: "off", edge: "solid", levelMark: "solid",
    art: "muted", rotation: "off", transitions: "crossfade", loupeMotion: "jump", focus: "solid", loupe: "ring",
    targets: "large", hoverInfo: "always", dockAutoHide: "never", confirmTimeout: "long"
});
var PRESETS = {"default": DEFAULT, legibility: LEGIBILITY, accessibility: ACCESSIBILITY};

// preset: "default" | "legibility" | "accessibility"; explicit: {option: value | "preset"}
function resolve(preset, explicit) {
    var base = PRESETS[preset] || DEFAULT, out = {}, e = explicit || {};
    for (var k in DEFAULT) {
        var v = e[k];
        out[k] = v !== undefined && v !== "preset" && OPTIONS[k].indexOf(v) >= 0 ? v : base[k];
    }
    return out;
}
// "Custom (based on …)" once any option differs from the chosen preset.
function isCustom(preset, explicit) {
    var base = PRESETS[preset] || DEFAULT, r = resolve(preset, explicit);
    for (var k in base) if (r[k] !== base[k]) return true;
    return false;
}

// Derived values components use.
var CARD_ROTATION = {full: 4, reduced: 2, off: 0};      // degrees; Default ±4–7°, Legibility ±2°
var TYPE_SCALE = {normal: 1.0, large: 1.25};
var CONFIRM_TIMEOUT = {normal: 5000, long: 15000};
var TARGET = {standard: 24, large: 44};

// Workspace numerals. Minuscule Roman with the terminal j (j, ij, iij … viij).
function roman(n) {
    var table = [[1000, "m"], [900, "cm"], [500, "d"], [400, "cd"], [100, "c"], [90, "xc"], [50, "l"], [40, "xl"], [10, "x"], [9, "ix"], [5, "v"], [4, "iv"], [1, "i"]];
    var out = "";
    for (var i = 0; i < table.length; i++) while (n >= table[i][0]) { out += table[i][1]; n -= table[i][0]; }
    return out;
}
function numeral(n, style) {
    if (!(n > 0) || n !== Math.floor(n)) return "";
    if (style === "arabic") return String(n);
    var r = roman(n);
    if (style === "capital") return r.toUpperCase();
    return r.replace(/i$/, "j");
}
