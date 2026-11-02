# Architecture

## One production process

`quickshell/shell.qml` owns independent feature loaders, scoped IPC and mutual
exclusion between launcher and card navigation. Rail, dock, cards, launcher,
notification server and OSD share singleton state within that process. Isolated
entry points exist for development, not one production process per widget.

Comments cite `DESIGN.md`, `DESIGN-SYSTEM.md` and `SURFACES.md` by section. Those are
the design documents kept outside this repository.

There is no desktop vellum surface, occupancy-driven background or window effect.
Compositors retain all window management and the existing wallpaper remains.

## v7 chrome and materials

`chrome-entry.qml` creates, per output, the rail and dock (`rail/`) plus two invisible
`Reservation` surfaces that hold their space; the visible surfaces ignore exclusive zones and
place themselves, so arrangement order does not matter. The dock reads
`DesktopState.windows` (adapters build it with `compositors/WindowLogic.js`) and acts through
`focusWindow`/`bringWindow`/`minimizeActive`; Hyprland dispatch strings come from the
`[dock.dispatch]` templates. Removable media is `services/RemovableMedia.qml` (event streams
from `udisksctl monitor` and `udevadm monitor`, snapshots from busctl, parsing in
`MediaLogic.js`); `rail/MediaBay.qml` draws the current device and `media/DeviceHand.qml`
hands it to the cards layer with `DeviceCard`.

The modules in `materials/` (`CardFace.js`, `CardPaint.js`, `DeviceArt.js`, `VellumPaint.js`
and the rest) are pure JavaScript painters (pixel arrays and the QML Context2D subset), shared
with the Node tests and the Chromium harness (`tests/visual/`). `scripts/skin/Materials.js`
re-exports them in one namespace for those tools; shell files import the module they need. `RasterCanvas` sizes a Canvas in device pixels so dither cells
sit on the output grid; faces, initials, the loupe, vellum and devices are painted once and
kept as textures. Reading options resolve in `config/Reading.js`; components read
`Settings.reading.<option>`, never the preset name.

## Compositor boundary

`compositors/DesktopState.qml` chooses an adapter after settings load. An explicit
`compositor` override wins; otherwise XDG_CURRENT_DESKTOP and session signatures
select Hyprland or Mango. Unsupported compositors expose unavailable state while
compositor-independent UI remains testable. `DesktopContext.qml` projects state
for a specific output. The common contract supplies outputs, focused output,
readiness/errors, capabilities, spaces, selection, focused title and activation.

The contract carries `modelKind` and an array of selected identifiers. Hyprland
uses native Quickshell workspace/toplevel objects and native activation, with an
additional IPC health socket, reconnect and periodic refresh. Special workspaces
remain filtered by the foundation's policy. Mango uses documented mmsg 0.18.4
get/watch streams for all-monitors, all-tags and all-clients, plus periodic full
snapshots and reconnect. Multiple tags may be visible and one client may occupy
several tags; membership is preserved. Normal click replaces the displayed tag
set; Ctrl/Shift-click toggles one member while refusing an empty set. Overview
(tag 0 in IPC) is kept distinct from normal tags. No Niri/River implementation is
advertised, but a new adapter need not fork the UI.

A disconnected adapter invalidates actionable state. Provider switching guards
against dispatching stale workspace objects through a tag adapter or vice versa.
Mango's independent snapshots can briefly reflect adjacent compositor moments;
there is no invented atomic cross-stream transaction. Real compositor acceptance
is still required, particularly output moves, hotplug, mixed scales and urgency.

## Artifacts and services

`artifacts/Geometry.js` is pure placement policy: rotated bounds, mixed aspect
ratios, a common centre axis, reversed distance ordering, scaling, bounded pages
and launcher reveal/centring. `ArtifactCard.qml` owns flip, selection and shared
pointer/keyboard gestures. `CardsLayer.qml` owns deployment and paging;
`ServiceCard.qml` supplies content/bindings. `VellumSheet.qml` separates material
reveal from scrolling page content. `Navigation.qml` keeps the originating card,
output, lane and expanded sheet state. Animation targets reverse rather than
queue completion callbacks. The persistent launcher surface uses one progress
coordinate for sequential reveal and centring, reversed on close.

Native service singletons under `services/` separate state from presentation:
PipeWire, Networking, Bluetooth, MPRIS and notification history. They retain
observed state when actions fail and surface errors. `CommandAction.qml` is the
bounded shared execution adapter for brightness and existing session utilities.
Arguments are arrays; network secrets never become process arguments. Suspend
requires a successful readiness-returning locker first; with
`commands.lockReturnsWhenReady = false`, Lock runs without a time limit and
Sleep is refused. Confirmation expires.
OSDs observe native changes and do not accept input or keyboard focus.

SNI and DBusMenu use native Quickshell integrations. Notifications own the normal
freedesktop bus name only when enabled. History persists privately and restores
old entries as inactive; native hot-reload entries are adopted without popup
replay. This does not replace authentication agents, a secure lock surface,
NetworkManager profile editing or MPD itself.

## Configuration, deployment and greeter

`config/defaults.toml` is the single source of defaults, types, per-key ranges
and allowed values. `lib/illuminated/config.py` is the only merger: `illuminated
apply` validates `~/.config/illuminated/config.toml` (with `[host.<name>]`
overrides) and writes `generated/resolved.json` plus the compositor and theme
files; on any error it writes nothing. `Settings.qml` reads `resolved.json`, plus
`ui.json` for Herbarium choices on keys config.toml does not pin, and never
merges or defines defaults (`quickshell/config/defaults.json` is generated from
the TOML for use before the first apply). `Theme.qml` and `Motion.qml` consume
those values; component files are not user configuration.

The installer (`lib/illuminated/install.py` and `deploy.py`) stages program files
into `~/.local/share/illuminated`, records hashes, atomically commits code and
retains reversible snapshots. With consent it adds one marked block to the
compositor config that loads the generated file; uninstall removes it byte for
byte. It never enables services or a DM.

The optional `greeter.qml` runs separately in a private compositor. It uses native
Quickshell Greetd for the framed greetd protocol and trusted session metadata,
not a custom authentication implementation. Authentication success starts the
retraction; only its completion or watchdog sends start_session. The native
client exits on success and the wrapper exits the greeter compositor promptly.
See GREETER.md for the security boundary and known upstream cancellation warning.
