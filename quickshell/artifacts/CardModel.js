// Card state → presentation (DESIGN-SYSTEM.md §3.5–3.12). Pure JavaScript with no
// QML types, so tests/card-model.test.cjs runs it under node. ServiceCard gathers
// service state into plain objects; CardSurface draws what these functions return.
//
// A surface is {base, ink, edge, wash, bands, chinFill, chinInk, patina, interior}:
//   base      cardstock colour of the whole face; ink is the text colour on it
//   wash      null | {colour, ink, level 0..1, axis "x" (from the left) | "y" (from the bottom),
//             foil: undefined | "gold" | "silver" (a four-tone foil instead of the flat colour)}
//   bands     null | {colour}: diagonal stripes in the frame only, over base and wash
//   chinFill  null | colour: solid chin content area (Reboot red, Bluetooth idle azure)
//   patina    null | {colour, coverage 0..1, stage 1..4}: verdigris spreading in from the edges;
//             the base is then copper foil (materials/CardFace.js copperAt)
//   interior  backs only: null | {base, stripe, washStripe}: tonal bands inside the
//             frame, so text over them needs a single ink (Reboot, charging battery)
// materials/CardPaint.js turns a surface into the textured face (foil, patina masks,
// dithered level marks, bands); the flat colours here remain the semantic values and
// the inks SplitText uses.

function clamp(value, low, high) { return Math.max(low, Math.min(high, value)); }

// Frame ≈10 px on a 154 px card; the chin is ≈19 % of a portrait card's height
// including the bottom frame. Everything scales with the card's short side.
function layout(width, height) {
    const k = Math.min(width, height) / 154;
    const frame = Math.max(4, Math.round(10 * k));
    const chin = Math.round(height * (width > height ? 0.2 : 0.19));
    return {
        k: k, frame: frame, chin: chin, period: Math.max(6, 10 * k),
        art: {x: frame, y: frame, width: Math.max(0, width - 2 * frame), height: Math.max(0, height - chin - frame)},
        chinArea: {x: frame, y: height - chin, width: Math.max(0, width - 2 * frame), height: Math.max(0, chin - frame)},
        interior: {x: frame, y: frame, width: Math.max(0, width - 2 * frame), height: Math.max(0, height - 2 * frame)},
        dogEar: Math.max(12, Math.round(18 * k))
    };
}

// Region a wash covers, in face coordinates.
function washRect(wash, width, height) {
    if (!wash) return {x: 0, y: 0, width: 0, height: 0};
    const level = clamp(wash.level, 0, 1);
    return wash.axis === "y" ? {x: 0, y: height * (1 - level), width: width, height: height * level}
                             : {x: 0, y: 0, width: width * level, height: height};
}

// Signal strength (0..1) → the four discrete patina stages.
const PATINA = [0, 0.17, 0.26, 0.36, 0.80];
function signalStage(strength) { return strength > 0 ? clamp(Math.ceil(strength * 4), 1, 4) : 0; }
function bars(stage) { return "▂▄▆█".slice(0, clamp(stage, 0, 4)); }

function percent(level) { return Math.round(clamp(level, 0, 1) * 100) + "%"; }

// Art changes uniformly as a secondary indicator (never takes the state colour).
function art(kind, level, present) {
    const l = clamp(level, 0, 1);
    if (kind === "volume" || kind === "microphone") return {saturation: 0.15 + 0.85 * l, luminance: 1};
    if (kind === "brightness" || (kind === "battery" && present)) return {saturation: 1, luminance: 0.4 + 0.6 * l};
    return {saturation: 1, luminance: 1};
}

function plain(c) {
    return {base: c.cardstock, ink: c.ink, edge: c.edge, wash: null, bands: null, chinFill: null, chinInk: c.ink, patina: null, interior: null};
}
function withChanges(surface, changes) {
    const out = {};
    for (const key in surface) out[key] = surface[key];
    for (const key in changes) out[key] = changes[key];
    return out;
}

// Session cards: "menu" turns to a list (Sleep), "confirm" turns to Confirm?
// (Shut Down, Reboot), "act" runs on click (Lock placed in a custom deck).
function sessionMode(spec) {
    if (spec && spec.alternatives && spec.alternatives.length) return "menu";
    return spec && spec.confirm === false ? "act" : "confirm";
}
// "Log Out" → "Log out?" (inline confirmation); "Shut Down" → "Shut down" (named action).
function sentence(title) { return title ? title.charAt(0) + title.slice(1).toLowerCase() : ""; }

// s: {present, level, charging, plugged, full}; plugged = external power, not charging.
function battery(s, c, numeralEnabled) {
    if (!s.present) return {surface: plain(c), glyph: "", value: "—", numeral: false};
    const held = s.plugged && !s.full;
    const surface = withChanges(plain(c), {
        wash: {colour: held ? c.power : c.battery, ink: c.onFill, level: s.level, axis: "y"},
        bands: s.charging ? {colour: c.power} : null
    });
    const numeral = !!numeralEnabled && s.level < 0.2;
    // The numeral clears the chin (label, glyph, value); charging stays visible in the frame bands.
    return {surface: surface, glyph: numeral ? "" : s.charging || (s.plugged && s.full) ? "ϟ" : held ? "⌁" : "",
            value: numeral ? "" : percent(s.level) + (held ? " • held" : ""), numeral: numeral};
}

// s: {available, level, muted}
function level(kind, s, c) {
    if (!s.available) return {surface: plain(c), glyph: "", value: "—"};
    const brightness = kind === "brightness";
    const colour = brightness ? c.brightness : s.muted ? c.volumeMuted : c.volume;
    const wash = {colour: colour, ink: c.onFill, level: s.level, axis: "x"};
    if (brightness) wash.foil = "gold";
    return {surface: withChanges(plain(c), {wash: wash, muted: !brightness && !!s.muted}),
            glyph: "", value: s.muted ? "Muted" : percent(s.level)};
}

// s: {enabled, connecting, failed, connected, stage, name}
function network(s, c) {
    if (s.failed) return {surface: withChanges(plain(c), {bands: {colour: c.critical}}), glyph: "✕", value: "Failed"};
    if (!s.enabled && !s.connected) return {surface: plain(c), glyph: "", value: "Off"};
    if (s.connected) {
        const stage = clamp(s.stage, 1, 4);
        return {surface: withChanges(plain(c), {base: c.copper, ink: c.onFill, chinInk: c.onFill,
                                                patina: {colour: c.verdigris, coverage: PATINA[stage], stage: stage}}),
                glyph: bars(stage), value: s.name || ""};
    }
    if (s.connecting) return {surface: withChanges(plain(c), {bands: {colour: c.verdigris}}), glyph: "", value: "…"};
    return {surface: plain(c), glyph: "", value: "On"};
}

// s: {available, enabled, connecting, failed, connected (count), name}
function bluetooth(s, c) {
    if (s.failed) return {surface: withChanges(plain(c), {bands: {colour: c.critical}}), glyph: "✕", value: "Failed"};
    if (!s.available || !s.enabled) return {surface: plain(c), glyph: "", value: "Off"};
    if (s.connecting) return {surface: withChanges(plain(c), {bands: {colour: c.bluetooth}}), glyph: "ᛒ", value: "…"};
    if (s.connected > 0) return {surface: withChanges(plain(c), {base: c.bluetooth, ink: c.onFill, chinInk: c.onFill}),
                                 glyph: "ᛒ", value: s.connected > 1 ? s.connected + " devices" : s.name || "1 device"};
    return {surface: withChanges(plain(c), {chinFill: c.bluetooth, chinBleed: true, chinInk: c.onFill}), glyph: "ᛒ", value: "On"};
}

// Sleep, Shut Down, Reboot (and Lock/Log Out when placed in a deck).
function power(kind, c) {
    if (kind === "suspend") return {surface: withChanges(plain(c), {base: c.sleepCard, ink: c.sleepInk, chinInk: c.sleepInk, edge: c.edgeInverted}),
                                    glyph: "☾", value: ""};
    if (kind === "poweroff") return {surface: withChanges(plain(c), {base: c.critical, ink: c.onFill, chinInk: c.onFill}), glyph: "", value: ""};
    if (kind === "reboot") return {surface: withChanges(plain(c), {bands: {colour: c.critical}, chinFill: c.critical, chinInk: c.onFill}), glyph: "", value: ""};
    return {surface: plain(c), glyph: "", value: ""};
}

// The back carries the front's surface across the whole face (continuous backs).
// Where front bands would put text across a two-ink edge, the interior uses
// tonal bands instead: Reboot red/lighter red, charging battery green or neutral pairs.
function back(kind, front, c) {
    const s = withChanges(front, {chinFill: null});
    if (kind === "reboot") return withChanges(s, {ink: c.onFill, interior: {base: c.critical, stripe: c.criticalTonal, washStripe: c.criticalTonal}});
    if (kind === "battery" && front.bands) return withChanges(s, {interior: {base: null, stripe: c.cardstockTonal, washStripe: c.batteryTonal}});
    return s;   // Bluetooth idle: neutral back; its chin tint is a front cue
}

// Ink for text at a point: what lies beneath decides (per-region inking).
function inkAt(surface, x, y, width, height) {
    if (surface.interior && surface.interior.base) return surface.ink;
    const r = washRect(surface.wash, width, height);
    const inside = surface.wash && x >= r.x && x < r.x + r.width && y >= r.y && y < r.y + r.height;
    return inside ? surface.wash.ink : surface.ink;
}

// h:mm from seconds; "—" when unknown (UPower reports 0).
function duration(seconds) {
    if (!(seconds > 0)) return "—";
    const minutes = Math.round(seconds / 60);
    return Math.floor(minutes / 60) + ":" + String(minutes % 60).padStart(2, "0");
}

// Colour of the surface at a point (the dog-ear previews the other face's corner).
function colourAt(surface, x, y, width, height) {
    if (!surface) return "transparent";
    const r = washRect(surface.wash, width, height);
    const inside = surface.wash && x >= r.x && x < r.x + r.width && y >= r.y && y < r.y + r.height;
    return inside ? surface.wash.colour : surface.base;
}

// Removable-media device card (SURFACES.md §2a): plain cardstock, used space as a silver
// foil fill rising bottom-up. s: {used 0..1 | null, busy, failed}
function device(s, c) {
    const surface = plain(c);
    if (s.used !== null && s.used !== undefined && s.used >= 0)
        surface.wash = {colour: c.silver || "#B9BEC4", ink: c.onFill, level: clamp(s.used, 0, 1), axis: "y", foil: "silver"};
    if (s.failed) surface.bands = {colour: c.critical};
    else if (s.busy) surface.bands = {colour: c.power};
    return {surface: surface, glyph: s.failed ? "✕" : "", value: ""};
}
// "38 / 64 GB": used / total in the largest unit that keeps the total under 1000.
function capacity(used, total) {
    if (!(total > 0)) return "";
    const units = ["B", "KB", "MB", "GB", "TB"];
    let u = 0, t = total;
    while (t >= 1000 && u < units.length - 1) { t /= 1000; u++; }
    const f = Math.pow(1000, u), fmt = v => v >= 100 ? Math.round(v) : v >= 10 ? Math.round(v) : Math.round(v * 10) / 10;
    return (used >= 0 ? fmt(used / f) + " / " : "") + fmt(total / f) + " " + units[u];
}
