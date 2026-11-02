# Feature inventory

Implementation is separate from runtime acceptance. The detailed evidence and
known failures are in [STATUS.md](STATUS.md); v7 details are in [V7.md](V7.md).

| Feature | Implemented | Verification / remaining boundary |
| --- | --- | --- |
| Unified shell | Independent loaders, feature isolation, scoped IPC, duplicate prevention, reload and recovery | Real Sway runtime; physical session startup still required |
| Compositor adapters | Auto-selection, capabilities, output contexts, readiness, reconnect/full reconciliation | Mango native mmsg with IPC fixture; Hyprland native adapter loads; neither compositor's live session verified |
| Hyprland workspaces | Filtering, activation, occupancy, urgency, focused title, output scoping | Foundation preserved through adapter; actual Lua dispatch/events pending |
| Mango tags | Multiple visible tags, multi-tag clients, normal replace and modified-click toggle, overview distinct | Pure projection + mmsg socket fixture; real renderer blocked by missing DRM |
| Rail and dock | Per-output left rail (launcher, workspaces with loupe, hand objects, removable media, tray, clock, paper corner) and top dock (every window, focus/bring/minimise, permanent or auto-hide); explicit reservations | Rail loads and reserves under Sway; Hyprland dispatch templates, `special:minimized` and dock order unverified |
| Cards | Hands dealt sideways from the rail at the object's height (a vertical lane for IPC tests and with the rail off), offscreen stack, leading card farthest, rotation-aware bounds, stagger, paging, lift, genuine flip, keyboard/focus | Actual QML, virtual pointer/keyboard and geometry tests; artwork placeholder |
| Direct controls | Landscape volume/brightness with horizontal fill/drag, click-vs-drag, wheel; portrait microphone; battery percentage/fill/charging state | Real virtual-node audio; physical brightness/battery unverified |
| Launcher | One vellum spread unfurling flat beside the rail, reverse close, interruptible persistent layer-shell surface, search, six pins (Alt+1…6), application list, keyboard/launch | Actual Wayland/runtime/app-launch marker; user desktop entries and focus restoration pending |
| Expanded sheets | Reveal/retraction, origin retained, scrollable pages independent of material motion, dismissal/focus | Real runtime; touch manipulation not implemented |
| Audio/OSDs | Sink/source mute and level, preferred device selection, native external sync, device loss/recovery, timed non-input OSDs | Actual PipeWire/WirePlumber virtual devices and server restart; hardware audio quality/routing pending |
| Brightness | brightnessctl snapshots/results, override, bounded/coalesced writes, external polling | Missing-device/error paths; no actual backlight writes |
| Network | Device state, Wi-Fi/rfkill guard, scans, saved/open/PSK connections, disconnect, errors | UI/no-service runtime; real NM/polkit/rfkill tests pending |
| Bluetooth | Power, scanning, pair/connect/disconnect, trust/forget confirmation, state/battery, delayed failure | UI/no-service runtime; requires existing PIN/passkey agent and real devices |
| Notifications | Freedesktop server, replace/expiry/dismiss/actions, plain text, history, DND, private atomic persistence/reload continuity | Real D-Bus calls, popup/history lifecycle, restart/reload; opt-in daemon takeover |
| Tray | Native SNI, primary/secondary/wheel, recursive DBusMenu in vellum | Real D-Bus transport with explicit application fixture; user apps/XEmbed boundary pending |
| Media | Native MPRIS metadata/player choice/transport/capability-guarded seek | Real D-Bus with fixture player; actual user applications/MPD bridge pending |
| MPD/rmpc | Optional official mpd-mpris integration guidance; existing setup retained | Bridge help inspected; no actual MPD playback claimed |
| Session | Expiring confirmation, cancel, lock/logout/suspend/reboot/poweroff; lock before suspend; lockers that run until unlock are never timed out, and Sleep refuses with them; normal inhibitors | Harmless command substitutes only (`session-ui` suite); actual locker and session actions unverified |
| Configuration | One `config.toml` with `[host.<name>]` overrides, validated by `illuminated apply` (types, per-key ranges, whole numbers, enums, cross-references); registry of groups, cards and keybinds for both compositors; warm dark/light palettes and three reading presets | v3: unit tests only. The runtime reload/invalid-file recovery evidence is from v2 JSON; generated foot/kitty/GTK palette files, not live external app sync |
| Installer | `illuminated install/uninstall [--purge]/restore/doctor`, explicit Arch package opt-in, dry-run, atomic code staging, hashes, backups, one reversible compositor block | Transaction and install round-trip tests in throwaway homes (byte-identical compositor restore); a refused uninstall changes nothing; packages/DM/services untouched |
| Removable media | udisks2 events and snapshots, udev identity, fourteen device kinds at life size, mount/open/eject/rename/format/properties, LUKS unlock via stdin | Parsers unit-tested; real devices, phones (gvfs/kio) and multi-partition drives unverified |
| Clipboard history | cliphist list in a sheet; entries restored through `wl-copy` | Not accepted on a real session |
| Lock screen (opt-in) | `WlSessionLock` + PAM, fallback locker when unconfirmed, latched across reloads | Not accepted with real PAM; see V7.md |
| Polkit agent (opt-in) | Prompt sheet for `PolkitAgent` requests | Not accepted with a real agent handover |
| Skins | `skin.json` + images for rail, dock, devices, card art, materials (data-driven; becoming QML skins, see the handoff) | Node format tests and Chromium renders; not loaded under Quickshell |
| Optional greeter | Right-hand reveal, dynamic trusted sessions, native greetd prompts, failure/cancel, retract-before-start, timeout/F2/watchdog | Real QML and native framed client with **simulated authentication**, no PAM or real session; experimental |

## Interaction contract

- Pointer, Up/Down and Tab select cards; lift preserves rotation. Right turns a
  card; Left returns. Enter/Space activates its front; right-click turns direct
  controls. Backs retain their dimensions and contain actual actions.
- Volume click toggles mute; horizontal drag and wheel adjust the observed level.
  Crossing the drag threshold prevents click on release. Muting does not erase
  the level fill. Brightness uses the equivalent landscape gesture. Microphone
  uses vertical dragging on its portrait card.
- Page Up/Down and footer buttons traverse bounded pages. Escape returns from
  sheets to cards, then retracts the deck. Outside click dismisses. Rail input
  remains available. Rapid requests converge to the newest target.
- Power confirmation expires after 15 seconds. Reopen its back to request a new
  confirmation. Dismissing the group cancels the pending action.

## Limits

Final textures, illumination and illustrations remain artistic work. There is no
shared desktop vellum, window effect, per-window parchment or placement constraint.
The shell does not draw a security lock screen or replace existing polkit/BlueZ
agents. VPN/enterprise/captive portals use existing tools. Notifications do not
advertise inline replies, rich images/markup or sounds. Legacy XEmbed tray icons,
a dedicated calendar/task system, clipboard manager, screen recorder, favourites
and drag-resizable sheets are not included. The greeter is optional and remains
experimental until real greetd/PAM/VT acceptance.
