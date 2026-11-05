# Configuration

Everything is configured from **one file**: `~/.config/illuminated/config.toml`.
You write only what you want to change. Each option, its default and its
allowed values are listed, with comments, in `config/defaults.toml`
(`illuminated defaults` prints it).

```sh
illuminated edit      # open config.toml in $EDITOR, then apply it
illuminated apply     # validate and regenerate after editing by hand
illuminated apply --check --diff   # validate only, and show what would change
illuminated watch     # re-apply every time the file is saved
```

`apply` validates the whole file first. Problems are reported with the key, its
line in config.toml, the reason and, for typos, a suggestion (`error:
dimensions.controlHieght (line 4): unknown key (did you mean dimensions.controlHeight?)`). A key you
did not write points at the nearest table you did, such as `[commands]`. If anything is wrong, nothing is written and
the running shell keeps its last good configuration. Every number has its own
range, and pixel sizes, durations and counts must be whole numbers
(`controlHeight = 40.5` is rejected rather than truncated); only
`deck.selectionLift` and `deck.dragThreshold` accept fractions. The ranges are in
`[schema.rules]` at the end of `config/defaults.toml`. Warnings, such as a group
too big for one page, are also shown in the Herbarium sheet and in
`illuminated status`.

## How values combine

| Layer | Where | Who writes it |
| --- | --- | --- |
| defaults | `config/defaults.toml` (shipped) | the project |
| your config | `config.toml` top level | you |
| this machine | `[host.<hostname>]` tables in `config.toml` | you |
| in-shell choices | `~/.config/illuminated/ui.json` | the Herbarium sheet |

Later layers win. **Tables merge key by key; arrays and scalars replace.**
Overriding `groups.power.cards` changes only that list. Every other group,
and the power group's glyph, stay as they are.

A key set in `config.toml` is *pinned*. The shell will not override it from the
Herbarium sheet; it tells you to change it in the file instead. A choice made in
the sheet applies only to keys the file leaves alone.

## What `apply` produces

Everything below is regenerated on each apply and is safe to delete:

```
~/.config/illuminated/generated/
  resolved.json   the only configuration file the shell reads (live-reloaded)
  hyprland.lua    autostart, keybinds, border colours for Hyprland
  mango.conf      the same for Mango
  foot.ini kitty.conf gtk.css   palette exports to include if you want them
```

`illuminated install` adds one marked block to your compositor config that loads
the matching generated file. After that, binds and borders follow `config.toml`.
Reload the compositor after an apply that changes them; `apply` tells you when.

## Common changes

```toml
[appearance]
mode = "light"                       # light | dark, or any palette you define

[palettes.moss]                      # a new palette; unspecified colours come from "dark"
paper = "#1c2119"
accent = "#b5d6a7"

[semantic]                           # meaning colours: one value in every mode
volume = "#F27EB0"

[rail]
hands = ["levels", "connections", "sound", "power"]   # hands dealt from the rail

[clock]
timeFormat = "h:mm ap"

[groups.power]
cards = ["suspend", "poweroff"]      # drop Reboot; Sleep's back still offers Lock and Log Out

[cards.notifications]
short = "Post"                       # used only when "Correspondence" would not fit

[reading.options]                    # single options over the reading preset
rotation = "off"                     # no tilt, whole-pixel placement: crisper text on low-DPI screens
confirmTimeout = "long"              # Shut Down / Reboot / Log out? wait 15 s, not 5 s, before cancelling

[groups.quick]                       # your own group
glyph = "✦"
cards = ["dnd", "lock"]

[binds]
"SUPER+Q" = "cards quick"
"SUPER+N" = ""                       # remove a default bind

[integration]
borders = false                      # keep your own Hyprland/Mango border colours

[commands]
lock = ["swaylock", "--daemonize", "--color", "24201b"]

[host.inspiron]
hardware.backlightDevice = "intel_backlight"
rail.width = 56
```

## The registry: groups and cards

- **`[groups.<name>]`** are decks. Each has `glyph`, `label`, `cards`,
  an optional `sheet` (a group with no cards opens its sheet directly, like
  `settings`), and `show`: `always`, `battery` (only on machines with a battery)
  or `player` (only while a media player exists). A group is reachable from
  `rail.hands`, `[binds]` and `illuminated cards <name>`.
- **`[cards.<kind>]`** are the built-in card kinds. Their behaviour is code, so
  you can't add kinds. You can change their `title`, `orientation`, `sheet`,
  `interaction`, a session card's `alternatives` and `confirm`. A session card
  with `alternatives` is a menu: a click turns it to a list of itself plus those
  entries (Sleep → Sleep, Lock, Log Out; entries cannot be menus themselves).
  Without them, `confirm = true` turns the card to "Confirm?" (Shut Down, Reboot)
  and `false` acts on click. In a menu, an entry with `confirm = true` asks
  inline ("Log out?").
  `short` is an optional shorter label: a chin or back header uses it only
  when the full title would not fit (Mic, Letters, Quiet, Net by default).
- **Colours**: `[palettes.<mode>]` holds material colours, which change per mode;
  `[semantic]` holds the colours that carry meaning (volume pink, brightness
  gold, battery green, power canary, Bluetooth azure, Network copper/verdigris,
  critical red), one value in every mode. Higher contrast comes from
  `reading.preset` (`legibility`, `accessibility`), not a separate palette.

Bind actions are the `illuminated` subcommands: `launcher`, `hide`,
`history`, `dnd`, `microphone`, `status`, `cards <group>`,
`volume up|down|mute`, `brightness up|down`. Chords use modifiers `SUPER`,
`SHIFT`, `CTRL` and `ALT` plus one key name (`SUPER+SHIFT+Q`,
`XF86AudioMute`).

## Rail, dock, reading presets and media (v7)

```toml
[appearance]
accent = "#8A9F7B"          # the rail and dock wash; weakened automatically if ink would fail 4.5:1
colourVision = "deutan"     # typical | protan | deutan | tritan

[reading]
preset = "legibility"       # default | legibility | accessibility
[reading.options]
rotation = "off"            # any option set here beats the preset; "preset" follows it

[pixel]
logical = 2                 # dither grain in output pixels

[dock]
mode = "auto"               # auto | permanent | autohide
[dock.outputs]
eDP-1 = "autohide"

[media]
scale = "auto"              # life size from the output, or 24 | 27 | 15.6 | 14q | 14f | compact
[media.overrides]
"1209:abcd" = "ereader"     # your own device's art by USB VID:PID
```

`[dock.dispatch]` holds the Hyprland dispatch templates; change them if your Hyprland's Lua
dispatchers differ (see docs/V7.md). `[rail] hands` lists the groups the rail's initials deal.

## Launcher pins, prompts and the lock (v7 second pass)

```toml
[launcher]
pins = ["firefox", "kitty", "org.gnome.Nautilus"]   # desktop ids, up to six; Alt+1…6

[features]
polkit = true    # this shell becomes the polkit agent; stop your current agent first
lock = true      # this shell's lock screen

[commands]
lock = ["illuminated", "lock"]      # required for features.lock to be used by Lock and Sleep

[lock]
pam = "login"                       # /etc/pam.d service
timeout = 3000                      # ms to wait for the compositor to confirm
fallback = ["swaylock", "--daemonize"]   # must return once locked; hyprlock is refused
```

`apply` warns while `features.lock` is on and `commands.lock` still runs another locker.
`illuminated lock` returns success only after a locker reports the screen locked.

## Skins and named commands

```toml
[skin]
path = ""                 # "" = ~/.config/illuminated/skin (docs/SKINS.md)

[commands.custom]         # what a skin button may run, as "command:<name>"
screenshot = ["grim", "/tmp/shot.png"]
```

A skin decides how things look and where the buttons are, and may add cards (`skin:<id>`) and
hands. It can't run anything that isn't named here.

## Commands and safety

Session commands are argv arrays, never shell strings. Sleep runs the lock
command first and suspends only after it exits successfully, so by default the
lock command must return once the screen is locked. `swaylock --daemonize` does
this. Both swaylock and hyprlock use the standard ext-session-lock protocol, so
either works on Hyprland and Mango.

Plain `hyprlock` keeps running until you unlock. To use it:

```toml
[commands]
lock = ["hyprlock"]
lockReturnsWhenReady = false
```

Lock then runs it with no time limit (other commands are stopped after 15
seconds, which would kill a running locker), and Sleep refuses with an
explanation instead of suspending only after you unlock. `apply` rejects plain
`hyprlock` while `lockReturnsWhenReady` is still `true`. To keep Sleep working,
use a locker that returns once the screen is locked. Test your locker before
relying on Sleep.

## Removed keys

Keys removed in the simplification pass are rejected by `apply`; the CHANGELOG's
"Removed keys" table names each replacement. The v2 `preferences.json` and
`machine.json` are not read, and `illuminated migrate` no longer exists.

## Environment overrides (testing only)

`ILLUMINATED_CONFIG_FILE` (alternate config.toml), `ILLUMINATED_RESOLVED`
(alternate resolved.json), `ILLUMINATED_SETTINGS` (alternate ui.json) and
`ILLUMINATED_CONFIG` (run a different quickshell folder side by side). Normal
use needs none of them.
