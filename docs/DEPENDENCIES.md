# Dependencies and service boundaries

Arch Linux is the reference platform. Use full upgrades to keep Qt/Quickshell
ABI-compatible. Executed reference: Quickshell 0.3.2, Qt 6.12, Arch archive
2026/10/30. `/opt/packages.txt` in fresh images records package versions; extracted test/build additions have separate JSON hash locks.
A newer stack requires its own acceptance. Production does not pin user packages.

| Purpose | Packages / existing components |
| --- | --- |
| Required UI | quickshell >=0.3.2 and its packaged Qt6 base/declarative/Wayland/SVG dependencies |
| Deployment/discovery | python3, bash, standard coreutils |
| Compositor | Existing compatible Hyprland (Lua reference 0.57) or MangoWC (IPC reference 0.18.4), including mmsg for Mango |
| Fonts | Alegreya Sans preferred; Qt fallback works, no Nerd Font dependency. Card text uses `typography.blackletter` (default UnifrakturCook, OFL, not in the official repos): put the TTF in `~/.local/share/fonts/` and run `fc-cache -f`, or set another installed blackletter. Without it cards fall back to the default sans |
| Audio | Existing pipewire + wireplumber; functioning existing session manager retained |
| Network | Existing networkmanager, session polkit agent |
| Bluetooth | Existing bluez and PIN/passkey agent; bluez-utils for diagnostics |
| Battery | Existing upower; absence produces unavailable state |
| Power profile | power-profiles-daemon, enabled (`sudo systemctl enable --now power-profiles-daemon`). Required for a real Profile on the Charge card: Quickshell cannot tell when the daemon is absent and reports its default ("Balanced"). `doctor` checks that the service is active |
| Backlight | brightnessctl; optional `hardware.backlightDevice` override |
| Lock | Existing configured locker; default swaylock --daemonize. Any ext-session-lock locker works on both compositors; plain hyprlock needs `commands.lockReturnsWhenReady = false` (see CONFIGURATION.md) |
| Power/logout | Existing logind/systemctl policy and compositor exit CLI; normal inhibitors apply |
| Media | Existing MPRIS players; optional official Arch mpd-mpris bridge for MPD/rmpc |
| Advanced connections | Existing nm-connection-editor/blueman or equivalent for enterprise/VPN/passkey workflows |
| Optional greeter | greetd, Quickshell Greetd integration, python3, private Sway, existing seat/PAM/VT configuration; optional text greeter such as agreety |
| Developer tests | nodejs, python, qt6-declarative/qmllint, bash, sway, mesa, grim, wtype, dbus, wayland, gcc, pkgconf, python-dbus-next |
| Mango source test build | meson, ninja, gcc, pkgconf, cjson, scenefx/wlroots and packaged dependencies, Xwayland disabled in test build |

Prefer official Arch repositories. Mango was not in the pinned official snapshot;
the developer build uses pinned upstream source and official build dependencies.
The installer does not fetch an AUR compositor or replace the user's compositor.
Keep already functioning services. For other distributions, install equivalent
Quickshell >=0.3.2/Qt packages and existing services manually; automatic package
installation is intentionally Arch-only and explicitly confirmed.

`illuminated doctor` reports required and optional commands, configuration
errors, compositor hook status and whether power-profiles-daemon is active. The
installer installs that package but never enables services; enable it yourself. The installer does not refuse to deploy when
Quickshell is missing or too old, so run `doctor` and check
`quickshell --version` yourself.

`--install-dependencies` (Arch only) runs
`sudo pacman -S --needed quickshell qt6-declarative brightnessctl swaylock power-profiles-daemon`
before deploying. pacman asks for its own confirmation; `--yes` does not answer
it, because `--yes` only permits the compositor config edit. The installer never
upgrades unrelated packages. Arch does not support partial upgrades, and
Quickshell builds against Qt's private API, so a newer quickshell on an older Qt
breaks at launch rather than at install. The installer therefore first runs
`pacman -Qu`, which only reads the local package database. If any upgrades are
pending, or the check cannot run, it refuses before installing anything and asks
you to run `sudo pacman -Syu` first. `--dry-run` skips the check and installs no
packages. Installer tests use stand-in `pacman` and `sudo` commands and never
touch real packages; uninstall never removes system packages.

Native Quickshell APIs supply most service bindings. Commands are bounded arrays
for existing utilities; Wi-Fi secrets go through the native API. The shell does
not enable services, replace polkit/BlueZ agents, start MPD, choose a terminal,
install a wallpaper daemon, modify a display manager or edit compositor config.
Notifications are off by default to avoid competing for the bus name.

The prepared cloud rootfs was extended through SHA256-verified extraction from
the same Arch snapshot: `dev/test-packages.json` and
`dev/mango-build-packages.json`. Its pacman DB does not register those additions;
a fresh Docker build installs them normally with signature checks. Do not treat
the extracted tree as a generally upgradeable system installation.

## v7 additions

| Need | Package (Arch) | Used for | Without it |
| --- | --- | --- | --- |
| udisks2 (`udisksctl`) | `udisks2` | removable media: events, mount, unlock, eject | the media bay stays empty and says so |
| `busctl`, `udevadm` | `systemd` (always present) | udisks snapshots as JSON; VID:PID, phones | — |
| `xdg-open` | `xdg-utils` | opening a mounted device in the default file manager | Open does nothing |
| `wl-copy` | `wl-clipboard` | restoring a clipboard-history entry | restore fails with a message |
| `cliphist` | `cliphist` | clipboard history; run `wl-paste --watch cliphist store` in your session | the sheet says history is unavailable |
| Pirata One, Germania One, Alegreya, Alegreya Sans | Google Fonts (SIL OFL), into `~/.local/share/fonts` | display faces | Qt substitutes a default face; `doctor` reports it |

`--install-dependencies` adds udisks2, wl-clipboard, cliphist and xdg-utils. Fonts are not
packaged here (they could not be fetched in the build environment); install them by hand.
Phones need gvfs (or kio) for `mtp://` / `afc://`; iPhones also need usbmuxd.
