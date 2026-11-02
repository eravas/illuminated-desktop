.pragma library
// Hands and cards a skin adds (docs/SKINS.md, "Cards and hands"), readable from plain JS so
// config/Settings can fall back to them without importing the skin's QML singletons.
// SkinStore fills it on every reload. Config always wins over a skin for the same name.
var hands = {}, cards = {};
function set(manifest) {
    hands = {}; cards = {};
    var h = (manifest && manifest.hands) || {}, c = (manifest && manifest.cards) || {};
    for (var n in h) if (h[n] && Array.isArray(h[n].cards)) hands[n] = {label: h[n].label || n, cards: h[n].cards.slice(), show: h[n].show || "always", skin: true};
    for (var k in c) if (c[k] && c[k].face) cards[k] = {title: c[k].title || k, short: c[k].short || "", orientation: c[k].orientation === "landscape" ? "landscape" : "portrait", skin: true};
}
function hand(name) { return hands[name] || null; }
// Skin cards are named "skin:<id>" wherever a hand lists them (config groups or skin hands).
function card(kind) { return typeof kind === "string" && kind.indexOf("skin:") === 0 ? cards[kind.slice(5)] || null : null; }
