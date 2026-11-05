Current revision: [v7-dev — rail, dock, removable media, textured materials](docs/V7.md), partly run under Quickshell (see [status](docs/STATUS.md)). Earlier revisions are in the [changelog](CHANGELOG.md) and Git history.

# The Illuminated Desktop — Herbarium

A portable, self-installing Quickshell rice for **Hyprland and MangoWC**. One
shell supplies the UI; separate compositor adapters preserve Hyprland workspaces
and Mango's multiple visible tags. Arch Linux is the reference platform.

Start with the [sequential testing guide](docs/TESTING-GUIDE.md). [Status](docs/STATUS.md)
records what has actually run, what is a fixture and what still needs local
acceptance. The [feature inventory](docs/FEATURES.md) includes limitations.

## The interface

A permanent left rail and a top dock (v7) replace the bar; the rail's illuminated initials deal hands of physical cards sideways onto the desk.
Cards travel in from the left in one row at the dealing initial's height (the
screen's middle when dealt over IPC or with the rail off); the leading card travels
farthest. Rotation-aware separation, pagination, selection lift, animated
vertical-axis flipping, keyboard navigation and interactive backs are shared
mechanics. Volume and brightness are landscape cards with horizontal live fills
and horizontal dragging. Other cards retain the 5:7 format. Click and drag are
separate gestures; muted volume remains visible.

Expanded controls unfurl within vellum sheets. The application launcher unfurls
from offscreen left, then slides the complete sheet to the centre. Search sits
above an illustrated placeholder area and scrollable application list. Motion is
interruptible and supports reduced motion. Artwork remains deliberately simple;
physical geometry and functional bindings are already implemented.

Native services provide notifications/history/DND, tray menus, audio/microphone
and device selection, network, Bluetooth, battery, MPRIS media and OSDs. Brightness
uses brightnessctl; session actions use the existing locker and session policy.
The [optional greetd greeter](docs/GREETER.md) is an independent process with a
right-hand vellum reveal and pre-session retraction. It is never enabled by the
rice installer. Ordinary wallpaper remains visible behind application windows.

## Install

You need Hyprland (0.57 or newer, with Lua config) or Mango (0.18), and
Quickshell **0.3.2 or newer**. See [dependencies](docs/DEPENDENCIES.md).

```sh
bash scripts/install.sh --dry-run     # show every change, write nothing
bash scripts/install.sh               # detect the compositor; ask before editing its config
#   --compositor hyprland|mango|both|none   --yes   --install-dependencies (Arch)
```

This sets up:

| What | Where | Removed by uninstall |
| --- | --- | --- |
| program | `~/.local/share/illuminated/` (ownership manifest) | yes |
| command | `~/.local/bin/illuminated` | yes |
| your settings | `~/.config/illuminated/config.toml`, `ui.json` | only with `--purge` |
| generated files | `~/.config/illuminated/generated/` | yes |
| compositor hook | one marked block in `hypr/hyprland.lua` or `mango/config.conf` | yes, byte for byte |

```sh
illuminated uninstall            # keeps config.toml and backups
illuminated uninstall --purge    # leaves no trace
illuminated restore              # roll the program back to before the last install
illuminated doctor               # dependencies, config errors, hook status
```

To update, run `bash scripts/install.sh` again from a newer source tree.
Program files you changed by hand are refused unless you pass `--force`; the
replaced version is kept for `illuminated restore`.

## Configure

Everything is set in **`~/.config/illuminated/config.toml`**, which holds only
your changes. That includes palettes, the rail's hands, which cards each group holds,
keybinds for both compositors, commands and per-machine overrides.
`illuminated edit` opens it and applies on save. `config/defaults.toml` lists
every option. See [configuration](docs/CONFIGURATION.md).

Notifications are off by default until you stop your previous notification daemon.
Configure and test your locker before using Sleep.

```sh
illuminated cards sound      # or any group name
illuminated launcher
illuminated history
illuminated status
illuminated isolate chrome   # one feature on its own (rail and dock)
illuminated stop
```

## Development and evidence

```sh
bash dev/build.sh
mkdir -p dev/cache
curl -fL https://github.com/mangowm/mango/archive/refs/tags/0.18.4.tar.gz -o dev/cache/mango-0.18.4.tar.gz
bash dev/run.sh bash dev/build-mango.sh
bash dev/run.sh bash dev/build-pointer.sh
bash dev/run.sh bash dev/test-all.sh
```

The prepared cloud runtime uses `dev/run-vfs.sh` in place of `dev/run.sh`.
Read [dev/README.md](dev/README.md) for pinned packages and both execution routes.
Tests execute real headless Sway, QML rendering, Wayland input, IPC and D-Bus.
Audio tests run actual private PipeWire/WirePlumber with virtual nodes. Mango,
MPRIS/tray application peers and greeter authentication use explicitly labelled
protocol fixtures where no genuine service/compositor is available.

Mango 0.18.4 built and parsed the integration configuration, but its actual
headless renderer failed without a DRM device. Neither Sway nor fixture tests
establish live Hyprland/Mango compatibility. Hardware, authorization and real
PAM/session startup still require local acceptance. Strict QML lint remains a
failing gate on documented native metadata warnings; it is not reported clean.

## History

This tree is a Git repository starting from the v7-dev tarball as received. Earlier
history (foundation-runtime-tested, artifact-services-checkpoint, the portable
branches and v7-dev) is in the history bundles of that tarball's `checkpoints/`;
clone a bundle to recover it.
