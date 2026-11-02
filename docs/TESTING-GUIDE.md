# Sequential testing, installation and recovery

Use this guide for the current build; [V7.md](V7.md) lists the v7-specific checks
(rail, dock, removable media, materials, skins, lock) in order. Keep the existing panel, notification daemon, locker, agents, MPD/rmpc
and compositor configuration available until each replacement passes acceptance.
The installer edits your compositor configuration only after showing the change
and getting your consent, and only by adding one marked block that
`illuminated uninstall` removes byte for byte. It never edits display-manager
configuration or enables services.

## 1. Preserve the current installation

Save your current Hyprland/Mango configuration and know how to reach a text TTY.
The project is a Git repository: check out or `git worktree add` an earlier commit
into a separate directory to compare; never merge it over installed source. The
pre-v7 history (tags `foundation-runtime-tested`, `artifact-services-checkpoint`)
lives in the history bundles of the original v7-dev tarball, not in this tree.

All commands below assume a terminal in the extracted project root. Until you
install, `python3 scripts/illuminated …` runs this tree's QML against your
`~/.config/illuminated` settings (packaged defaults if you have none), so isolated
tests need no environment variables and change nothing outside that directory.
After installing, the same subcommands are available as `illuminated …`. Stop an
isolated process with Ctrl+C before moving to another stage. Scoped shutdown of
the cohesive process is `illuminated stop`; do not use a global pkill quickshell.

If you merged lines from the v2 `integration/*.example` snippets into your
compositor config, remove them before installing v3, so the shell is not started
by two autostart mechanisms.

## 2. Check dependencies and baseline services

Read [DEPENDENCIES.md](DEPENDENCIES.md). Check `quickshell --version` (reference
0.3.2) and a coherent Qt stack. Keep existing PipeWire/session manager,
NetworkManager, BlueZ and polkit agents. Check `hyprctl version` in Hyprland or
`mango -v` and `mmsg get all-monitors` in Mango. Do not replace an existing working
compositor just to match the developer image.

```sh
python3 scripts/illuminated doctor
```

`doctor` reports dependencies, configuration errors and whether the compositor
hook is present. Missing optional commands do not prevent unrelated features.
Production needs a supported compositor; Sway is only the cloud test host. A newer
Quickshell should be accepted locally before replacing the previous shell.

Developer checks: `bash scripts/validate.sh` runs Bash/Python syntax, validates the
packaged defaults with `illuminated apply --check`, runs the JavaScript policy
tests and the Python configuration/installer/session tests, then strict QML lint
when qmllint is available. The v3 reference run has 19 JavaScript and 69 Python
tests. Strict lint was not available for v3; in the last run that had it (v2), it
returned 1 for documented upstream type metadata warnings, so inspect the complete
diagnostics. Reproduce runtime suites separately as described in
[dev/README.md](../dev/README.md).

## 3. Install and exercise rollback

Rehearse first in a throwaway home directory. `t` runs a command with HOME pointed
there and the XDG overrides cleared, so nothing touches your real files:

```sh
export TESTHOME=$(mktemp -d)
t() { env -u XDG_CONFIG_HOME -u XDG_DATA_HOME -u XDG_STATE_HOME HOME="$TESTHOME" "$@"; }
mkdir -p "$TESTHOME/.config/hypr" && cp ~/.config/hypr/hyprland.lua "$TESTHOME/.config/hypr/"
t bash scripts/install.sh --compositor hyprland --dry-run   # shows every change, writes nothing
t bash scripts/install.sh --compositor hyprland --yes
t "$TESTHOME/.local/bin/illuminated" doctor
t bash scripts/install.sh --compositor hyprland --yes       # again: an idempotent update
t "$TESTHOME/.local/bin/illuminated" uninstall
cmp ~/.config/hypr/hyprland.lua "$TESTHOME/.config/hypr/hyprland.lua" && echo restored
t python3 scripts/illuminated uninstall --purge             # removes config.toml, ui.json, backups
```

Use `--compositor mango` with `~/.config/mango/config.conf`, or `both`. The
installer never creates a compositor config that does not exist.

Then install for real:

```sh
bash scripts/install.sh --dry-run
bash scripts/install.sh            # detects the compositor, shows the diff, asks before editing
illuminated doctor
```

Options: `--compositor hyprland|mango|both|none` (`none` skips the compositor
hook), `--yes` (edit without asking), `--force`, and `--install-dependencies`
(explicit Arch package opt-in; it refuses while system upgrades are pending, so
run `sudo pacman -Syu` first). Where each file goes is tabulated in the README.

Updating means running `bash scripts/install.sh` again from a newer tree. Program
files you changed by hand are refused unless you pass `--force`; the replaced
versions are kept, and `illuminated restore` puts back the program files replaced
by the last install or update. Backups and the ownership manifest live beside the
program in `~/.local/share`; never remove them while you may need `restore`.
`illuminated uninstall` keeps `config.toml`, `ui.json` and backups;
`illuminated uninstall --purge` removes those too. Neither removes packages. No
operation manages boot, drivers or partitions.

If a managed program file was changed by hand, `uninstall` refuses before
removing anything: the compositor hook, launcher, generated files and settings
all stay. Review the change, then run `illuminated uninstall --force`, which keeps
a snapshot of the changed files among the backups.

## 4. Inspect the rail and dock

```sh
python3 scripts/illuminated isolate chrome
```

The rail and dock select the active compositor adapter. Check urgency,
occupied/empty spaces, output scoping, window moves, fullscreen, mixed scales,
hotplug and the rail and dock reservations (72 px each). The rail's workspace
list scrolls when it runs short; scrolling must not switch focus. Waybar
coexistence creates two reservations until you stop one panel.

Startup on an idle Hyprland desktop (no input after launch): within about a
second the rail should list workspaces with the loupe over the active one; it must
not wait for the next compositor event (v5.1 took 10–12 s). The dock lists every
window; follow V7.md steps 2–5 for the dock dispatch checks.

Under Hyprland, compare ordinary/named/special workspace filtering and native
activation with hyprctl. Under Mango, first show two tags using normal compositor
bindings: both should remain active, and a window belonging to two tags should
be counted in both. Normal click selects one tag; Ctrl/Shift-click toggles a tag
while refusing an empty selection. Check overview separately. Compare with:

```sh
mmsg get all-monitors
mmsg get all-tags
mmsg get all-clients
```

Do not interpret a fixture pass as native Mango acceptance. On adapter failure,
controls become non-actionable and status exposes the error. A new compositor
session needs a new shell process so startup environment detection is current.

## 5. Test cards in isolation

```sh
python3 scripts/illuminated isolate cards
```

Sound opens immediately. Cards must start stacked above the screen, aligned to
one vertical lane. Leading card travels farthest. All final rotated edges are
separated. Volume is landscape; microphone/devices are 5:7. Pointer/Up/Down/Tab
selects; lift preserves rotation. A click does the card's main thing: Sound
mutes, Network and Bluetooth toggle their radios, Charge and Devices turn over.
Those whose click acts turn over from the **dog-ear** (top-right corner, at least
24 × 24 px) or right-click; Light has no back. Left, Escape or a click on the desk
turns a card back (a second Escape or desk click closes the deck). Controls on
backs remain usable during/after a genuine animated turn. More space opens a
vellum sheet, not a separate conventional dialog.

Set `reading.options.rotation = "off"` (or "Align cards to grid" in the Herbarium sheet): cards
deal untilted at whole pixels, and hairlines and text lose their staircase and
colour fringes. Long titles switch to their `short` label only when they would not
fit (Microphone → Mic, Correspondence → Letters, Quiet hours → Quiet).

Sound: click mutes, drag **horizontally**, wheel adjusts. Drag release must not
mute. Muted keeps the level and shows a greyed pink fill with *Muted* in the chin.
Microphone uses vertical drag in its portrait card. Use quick close/reopen/page/group changes
and Escape/outside click. Short outputs paginate with Page Up/Down or footer
buttons; no card may overlap or become inaccessible. Check that selection lift
never causes collisions. If unavailable, cards report that state rather than
presenting synthetic levels as working devices.

## 6. Test launcher in isolation

```sh
python3 scripts/illuminated isolate launcher
```

The spread unfurls flat from its left edge in the space right of the rail and
below the dock (no centring phase); closing reverses it. The left page holds the
blackletter search field and six pin plates (`launcher.pins`, Alt+1…6), the right
page every application. Check keyboard focus, Up/Down, Enter, scrolling, no results, Escape/outside
click and your real application entries, including Terminal=true entries. The
surface must be a layer-shell overlay rather than a tiled window. The illustration
is a placeholder. Focus restoration and scaling still need physical acceptance.

## 7. Coherent shell

In `~/.config/illuminated/config.toml`, initially leave notifications off and
enable only the features you want, then run `illuminated apply`:

```toml
[features]
rail = true
cards = true
launcher = true
notifications = false
```

```sh
python3 scripts/illuminated start
# In another terminal:
python3 scripts/illuminated status
python3 scripts/illuminated launcher
python3 scripts/illuminated cards sound
python3 scripts/illuminated hide
```

Rail objects deal their hand on that output at their own height; IPC uses the
compositor's focused output. The rail stays clickable while a hand is out. Launcher/card requests
dismiss each other. Repeated toggles reverse/converge without duplicate surfaces.
Running start again must not duplicate the shell. With `illuminated watch` running,
edit config.toml while a sheet is open: appearance.mode, motion.reduced and a
feature switch should apply live. An invalid value (for example
`dimensions.controlHeight = 40.5`, or `4000`) must be rejected with the key named; nothing is
written and the running shell keeps its last configuration. Correcting it must
recover. Add a `[host.<your hostname>]` override, then remove it, to test
precedence and recovery. Set `appearance.mode` in config.toml, then try changing
it from the Herbarium sheet: the sheet must refuse and name the key to edit.

## 8. Audio, microphone and OSD

Open sound; turn Devices and open its sheet. Compare volume/mute, input gain/mute
and input/output choice with existing tools. Change levels externally using wpctl;
card fill and OSD should follow without stealing focus. Remove/reconnect a default
device; only when safe, restart user audio services and verify recovery. Hardware
speakers, microphone recording, headset/Bluetooth routing and media keys require
local testing. Cloud coverage used actual private services with virtual nodes.
Toggle features.osd to test independent enablement; isolate osd observes real
service changes without creating cards.

Recovery: inspect `wpctl status`, existing user service logs and shell status;
restore your prior audio utility if routing remains uncertain. Do not change
system-wide audio configuration to repair the shell UI.

## 9. Brightness and battery

Open light. Light is landscape with a gold fill on the cardstock (flat for now;
the dithered foil comes later) and art that dims with level; drag/wheel and
sheet slider adjust it. Compare `brightnessctl --class=backlight info` and restore
the original level. Set `hardware.backlightDevice` (under `[host.<name>]` if it differs per machine) only if automatic selection is wrong.
Permission/device failures must be visible. Writes coalesce; observed results
update the UI. External changes poll every three seconds when OSD is enabled;
opening the card requests a snapshot otherwise. External DDC monitors remain
with existing tools. No physical backlight write was cloud-tested.

Charge (battery) and the rail converter should match UPower. The green wash rises
through the frame and chin with the level, and the grey placeholder art dims with
it. Check each state:

- discharging: green, no bands, no glyph;
- charging: canary bands in the frame (visible even at 100%), bolt glyph;
- plugged in and not charging: canary wash, plug glyph, chin `92% • held`;
- full on AC: green, bolt, never "held";
- below 20% with `reading.options.lowChargeNumeral = "on"` (or the Legibility preset):
  the chin clears and a large numeral sits over the art.

Turn it over: Profile, Remaining and Limit (Limit only where
`/sys/class/power_supply/BAT*/charge_control_end_threshold` exists). Real battery
behaviour remains unverified.

## 10. Connections and expanded sheets

Open connections. Network: a click toggles the Wi-Fi radio. Expect neutral when
off, verdigris bands while connecting, copper with a verdigris border that grows
with signal (four stages, bars glyph) when connected, and red bands with *Failed*
after a wrong passphrase. Turn it over from the dog-ear: the connected network and
the strongest others, then *See All ›*. Bluetooth: neutral off, azure chin when on
with nothing connected, azure bands while pairing, solid azure when connected, red
bands on failure; its back lists connected devices beside a ᛒ in the margin, then
*Devices ›*. Open the Network sheet and verify radio/hardware block,
scanning, saved/open/PSK connection and disconnect on a safe network. Passphrases
are cleared and passed via native API, not shell arguments. Errors and external
state changes must update. Enterprise/VPN/captive portal management remains in
your existing tools. Keep a backup network path before disruption.

Bluetooth sheet: power, scan, pair/connect/disconnect, trust/untrust, explicit
forget confirmation, device removal and battery. Existing BlueZ agent handles
PIN/passkey prompts. Missing services/devices should remain readable and recover
when available. Cloud tested no-service UI paths, not real NM/BlueZ authorization.

For both sheets, scrolling content must not move the material roll. Escape
returns to the originating cards; outside click and rapid group replacement must
not leave orphan surfaces. Recovery: existing connection editor, bluetoothctl/
blueman and system service logs; disable only the shell feature if needed.

## 11. Notifications and history

Deliberately stop the previous notification daemon before enabling
features.notifications. For isolation, stop the cohesive shell and run:

```sh
python3 scripts/illuminated isolate notifications
```

Use real applications or notify-send: replace, timeout, persistent notifications,
actions, dismiss, DND, restart and source reload. History/dnd IPC controls the
cohesive shell's service. DND suppresses popup display while keeping history.
History is private atomic JSON under
`${XDG_STATE_HOME:-$HOME/.local/state}/illuminated/notifications.json`; it contains
notification text. Clear history removes retained entries. Restart restores old
entries inactive; QML reload adopts native tracked entries without replaying
popups. Rich markup/images, inline reply and sounds are not advertised.

If another daemon owns the name, stop this feature and resolve that conflict.
Rollback by disabling notifications and restarting your previous daemon with its
normal method. Do not run multiple notification-server processes as a workaround.

## 12. Tray application menus

Stop any existing test owner, start the shell, and click the rail's tray mark (or
run `python3 scripts/illuminated cards tray`).
Use real SNI applications: left activation, middle secondary action, wheel,
right-click DBusMenu, submenu back, checkable actions and application exit while
menu is open. Menus should be interactive vellum content. Legacy XEmbed-only icons
are outside scope. Automated transport used explicit D-Bus fixture applications;
your applications remain to be accepted. Restore the existing panel's tray if
necessary; avoid competing watcher/test processes.

## 13. Media and existing MPD/rmpc

Run `python3 scripts/illuminated isolate media` or open media in the cohesive shell.
Test actual MPRIS applications, selection, metadata, playback, transport and seek
only where supported. Read [MPD integration](../integration/mpd-mpris.md); MPD does
not inherently expose MPRIS. The optional official mpd-mpris bridge must use your
existing server address/socket. It does not replace MPD, rmpc or playlists. Real
MPD playback was not cloud-tested. Missing/exiting players should clear stale
controls. Fall back to your existing player if any capability is inconsistent.

## 14. Session controls — deliberate local acceptance

Save work and first test the configured locker manually on all outputs. The
readiness-returning default is swaylock --daemonize. Suspend proceeds only after
successful lock readiness. If you use plain hyprlock, set
`commands.lockReturnsWhenReady = false`: Lock must then stay locked well past 15
seconds without the locker being killed, and Sleep must refuse with an
explanation.
The Session deck is Sleep, Shut Down and Reboot. Sleep turns over to Sleep /
Lock / Log Out: Sleep and Lock act at once; Log Out turns into "Log out?" and acts
on a second click. Shut Down and Reboot turn over to "Confirm?" and act on a
second click on the card. Clicks during the turn and for 400 ms after it are
ignored (`confirm.armDelay`). Escape, a click on the desk, selecting another card
or 5 s without input (15 s with `reading.options.confirmTimeout = "long"`) turn the
card back and cancel. The deck
closes once an action has started.

Automated checks use marker-file commands, **never actual power/session actions**.
Accept real actions separately with your normal inhibitor/polkit/session policy.
Empty commands.logout uses the chosen compositor's exit command. No force flags
bypass inhibitors. Recovery: save logs and restore existing session keybindings;
never test actual shutdown while work is unsaved.

## 15. Integrate either compositor reversibly

`illuminated install` adds one marked block to `~/.config/hypr/hyprland.lua` and/or
`~/.config/mango/config.conf`, after showing the diff and asking. The block loads
`~/.config/illuminated/generated/hyprland.lua` or `mango.conf`, which carry
autostart, keybinds and border colours from config.toml. `[integration]` switches
each of the three off, a default bind is removed with `"CHORD" = ""`, and
`illuminated apply` says when you need to reload the compositor.

Checked against compositor source but not yet on a real session
(docs/evidence/compositor-includes/):
- Hyprland: the block runs the generated file through `dofile` (or `loadfile`)
  inside `pcall`. Hyprland 0.57 loads Lua's standard libraries, so `dofile`
  exists; if the generated file is missing, Hyprland logs `illuminated: …` and
  starts without the binds.
- Mango: the block uses `source_optional=`, which Mango 0.18.4 skips when the
  file is missing. The generated `exec_once=` autostart follows Mango's
  documentation. Neither has been run on Mango.

Log into each compositor separately and check `illuminated status`: correct
provider, workspace/tag semantics, focus/output, startup exactly once and clean
shutdown. Keep existing tag/workspace bindings; resolve chord conflicts in
`[binds]`. `illuminated uninstall` removes the block, restoring the file byte for
byte. Palette exports for foot, kitty and GTK are generated beside the compositor
files; include them yourself only if you want them.

## 16. Optional greeter and final acceptance

The ordinary shell does not need this component. Read [GREETER.md](GREETER.md)
before any opt-in. Safe cloud tests simulated authentication; they did not test
PAM, greetd daemon operation or session/VT handoff. Preview has no authentication.
Keep your existing DM and working text login until administrator-owned deployment,
real PAM failure/cancel/multi-prompt, crash recovery, F2/watchdog fallback, trusted
session discovery, correct retraction and session start all pass locally.

No desktop/background vellum feature exists in this build. The existing wallpaper
should remain visible behind ordinary application windows. Final acceptance should
cover both compositor sessions, suspend/resume, output unplug/replug, mixed scales,
service restarts and normal daily workflows before retiring fallback utilities.
