# Status

This is the single record of what has been verified, and how. It replaces the deleted
NEXT-SESSION, HARDENING, RUNTIME-REPORT, CARD-HARDENING-V2, CONFIG-V3, DEVELOPMENT-REPORT
and VALIDATION reports. The plan is in [SIMPLIFICATION-HANDOFF.md](../SIMPLIFICATION-HANDOFF.md).

Labels: **V** verified at runtime (headless Sway, Quickshell); **U** unit or static checks
only; **L** needs local acceptance on the Inspiron (Hyprland).

## How the runtime is run here

The cloud container is Ubuntu 24.04 without a Docker daemon, not Arch. `dev/cloud-setup.sh`
builds the Dockerfile's userspace (same dated archive 2026/10/30, same packages: Quickshell
0.3.2, Qt 6.12, Sway, PipeWire, Mango/mmsg 0.18.4) as a directory from the Arch bootstrap
tarball; `dev/run-chroot.sh` runs a command in it with the `run.sh` contract (no network,
UID 1000, private tmp/run/home). Every **V** below ran this way:
`bash dev/run-chroot.sh bash dev/test-all.sh`. Mango's release tarball was reproduced from
git with the pinned SHA-256 (GitHub's archive endpoint was blocked).

## Baseline: v7-dev as received (commit `5137877`), in this runtime

| Check | Result |
| --- | --- |
| Node tests | 166/166 |
| Python unittest | 80/80 |
| qmllint (non-strict) | exit 0, 91 warnings |
| foundation | **fail**: launcher reopen (deterministic here, not intermittent) |
| artifacts | **fail**: timing (keyboard flip or DBusMenu click; varies) |
| smoke, audio, compositor, greeter, session-ui | pass |
| reload, single-config | **fail**: `SkinElement.qml` TypeError (below) |

Two baseline bugs surfaced: every skin element threw `Property 'layer' … is not a function`
on first paint and drew nothing (Qt 6.12's `Item.layer` shadows a method named `layer`), and
the foundation and artifacts failures track GUI-thread paint time (Phase 5 measurements).

## Current (HEAD)

| Check | Result |
| --- | --- |
| Node tests | 169/169 |
| Python unittest | 79/79 |
| qmllint (non-strict) | exit 0, 85 warnings (Quickshell type-metadata gaps) |
| foundation | **fail**: launcher reopen, same cause as baseline (first-paint stall) |
| artifacts | pass; intermittent timing failures remain (about 1 run in 3) |
| smoke, audio, reload, compositor, greeter, single-config, session-ui | pass |

## Phase 0: repository (done)

The tree is a Git repository. `checkpoints/` (30 MB: history bundles and the foundation
tarball) and `artifacts/` (4.9 MB of test logs) are not committed; the original tarball
keeps them. The compositor include evidence moved to `docs/evidence/compositor-includes/`.

## Phase 1: deletions (done; verified at runtime in this session)

Done in a Claude session **without Qt, Quickshell or qmllint**: no Qt runtime was available
and the package index refused the PySide6 download. What was checked there:

- Node tests (153/153; the 13 fewer are the per-file QML structure checks of deleted files);
- Python unittest (78/78);
- `illuminated apply --check`;
- both skin build scripts (images byte-identical to the committed skin after the
  `Materials.js` move);
- the Chromium visual harness, which still renders every contact sheet.

Everything touching QML was then **U**. Verified here at runtime (the table's U labels
for QML now read V, covered by the named suites):

- the bar removal, Controls removal and the foundation probes rewritten against a hand and
  the launcher: smoke, foundation up to the launcher-reopen step (baseline failure), reload,
  single-config;
- v6 shims and reading options: single-config, reload, artifacts;
- CommandAction in `services/`: compositor (no "is not a type"), session-ui, artifacts.

Phase 1 broke one thing: 1.5 removed `NotificationHub.now` as unread, but `popups` filters on
it, so popups never expired (ReferenceError). Fixed in `fix: restore popup expiry`, which also
replaces the 2 Hz timer with one that runs only while a popup is pending (V: artifacts
notification steps).

| Commit | Change | Label |
| --- | --- | --- |
| remove: v6 top bar | bar UI, `[bar]`, `[bar.opens]`, `features.bar`, `dimensions.barHeight`, bar validation; `bar.timeFormat` moved to `clock.timeFormat` (rail clock, lock screen) | V |
| remove: Controls diagnostic window | Controls, Audio, Network tools; `controls` CLI/IPC/bind; CommandAction moved to `services/`; the foundation suite's show/hide probes rewritten to use a hand and the launcher | V |
| remove: v2 migration | `illuminated migrate` and its TOML writer | U (Python) |
| remove: v6 compatibility shims | highLegibility, battery.lowChargeNumeral, deck.rotation/aligned, confirm.timeout; Herbarium align toggle now sets `reading.options.rotation` | V |
| move: Materials.js facade | to `scripts/skin/` | U (Node, skin build, harness) |
| remove: five reading options | disabled, focusRing, overflow, stateText, stickySelect | V |
| remove: dead timer and unused functions | NotificationHub 2 Hz timer; four functions | V |
| docs | superseded reports deleted; README, ARCHITECTURE, FEATURES, TESTING-GUIDE, CONFIGURATION, DEPENDENCIES, SOURCES, V7 updated; CHANGELOG "Removed keys" | — |

Size: QML files 96 → 83. Code (QML/JS/Python/CJS/shell/TOML, excluding the generated
`defaults.js`) about 14.9k → 14.1k lines. User-facing config keys 350 → 326. Archive
46 MB → 20 MB compressed: a 10 MB tree, mostly skin images and the wallpaper, plus about
10 MB of `.git`, which holds the same images once more.

### Deferred from Phase 1, and why

- **The `origin: "top"` deck path** (`Navigation.origin/triggerX`, `CardsLayer` `fromLeft`
  branches, `Geometry.deck`). It is not bar-only: it is Navigation's fallback when
  `features.rail = false`, and the `artifacts` runtime suite's deck assertions (card centres
  on an x-lane, pagination at 320×240) and `audio.qml` are built on it. Removing it means
  re-deriving those assertions for `Geometry.dealLeft`, which needs a runtime to check. See
  handoff Phase 1.7.
- **Groups `light` and `session`.** They duplicate `levels`/`battery` and `power`, but the
  `artifacts` suite and `test_config` use them. Remove them with the top-origin path.
- **Groups `sound` and `media` are kept on purpose.** They are the only decks holding the
  microphone, Devices (outputs) and Music cards; no rail hand includes those.
- **Mango `DesktopContext` `allOutputs`.** It is now always `false`. The adapters' parameter
  is left in place for Phase 2.2.

### Corrections to the handoff found while doing Phase 1

- `bar.timeFormat` was not bar-only: the rail clock and lock screen read it. It moved to
  `[clock]`.
- `sound`/`media` are not bar-only (above).
- A `.gitignore` entry `artifacts/` also matches `quickshell/artifacts/`. Ignore patterns must
  be anchored (`/artifacts/`).
- Moving `CommandAction` to `services/` makes `compositors/` and `services/` import each other
  (MangoAdapter → services, SessionState → compositors). The baseline already had the same
  pattern between `skin/` and `artifacts/` and loaded fine, but confirm that no "is not a type"
  error appears in the Mango adapter suite.

## Commits outside the phases

| Commit | Change | Label |
| --- | --- | --- |
| dev: Docker-less Arch runtime for cloud hosts | `dev/cloud-setup.sh`, `dev/run-chroot.sh`, a test keeping them equal to the Dockerfile | V (ran every suite) |
| fix: SkinElement layer() shadowed by Item.layer | rename the method; skin elements draw again | V (reload, single-config) |
| fix: restore popup expiry | see Phase 1 | V |
| perf: opt-in paint profiling | `ILLUMINATED_PROFILE=1`, `tests/runtime/profile.py` | V |

## Phase 1.7: deferred deletions (done)

| Commit | Change | Label |
| --- | --- | --- |
| remove: top deck origin | `Navigation.origin/triggerX`, `open()`'s `from`, `CardsLayer` `fromLeft`, `Geometry.deck` and its tests; the dock's `from: "top"` | V (artifacts, audio, session-ui; unit) |
| remove: light and session groups | defaults, tests repointed to levels/battery/power | V (artifacts, session-ui, single-config) |

Not in the handoff: the **dock also dealt top-origin hands** (`Dock.qml` passed
`from: "top"`). Dock-dealt hands now come from the left at the dock element's height,
clamped under a permanent dock (L: the example skin's dock button). Test changes keep each
assertion's intent: one row on the lane, left to right, clear of the rail; pagination at
320×240 walks every page and finds all three cards; the tray-menu click waits for the sheet
and uses its real position; the "empty table" return click lands right of the rail, which
is outside the cards layer's input mask.

## Phase 2: stable models and idle wakeups (done)

| Commit | Change | Label |
| --- | --- | --- |
| perf: stable dock model | `ScriptModel { objectProp: "id" }`; entries read the live window via `DesktopState.windowById` | V (Mango fixture), L (Hyprland) |
| perf: stable rail workspaces; drop the context title | numerals keyed by id; `title` removed from both adapters, `MangoLogic.context`, `DesktopContext`; `allOutputs` parameter removed | V (Mango fixture), U/L (Hyprland) |
| perf: read the backlight from sysfs | first read and writes via brightnessctl; polling reloads `actual_brightness`/`max_brightness` | V (fixture sysfs tree), L (real backlight) |
| perf: Hyprland reconciles on reconnect only | 10 s reconcile removed; settle loop, seed and health socket kept | U, L |

Deviation: the handoff suggested native `HyprlandToplevel` objects for the Hyprland dock
model. One keyed path for both adapters is simpler and runs here (Mango fixture); Hyprland's
array is still rebuilt per event in JS, but delegates survive. Tests: the compositor suite
now has two clients; a title change keeps both dock entries and all nine tag numerals as the
same objects (0 kept with the old models, so the test discriminates) and shows the new title.
Brightness: the artifacts suite writes the fixture sysfs file from outside and sees the new
level, and asserts brightnessctl was called for reads at most twice in the whole run.
`udevadm monitor` multiplexing was not done: sysfs reload on the existing timer was enough.

## Phase 3: ServiceCard and card plumbing (done)

| Commit | Change | Label |
| --- | --- | --- |
| refactor: per-kind card adapters | `artifacts/kinds/`: one adapter per family, backs in their own files; ServiceCard 555 → 133 lines; only the battery card binds UPower | V (artifacts, audio, session-ui unmodified) |
| remove: card behaviour keys from config | `cards.*.orientation/interaction/alternatives` (48 keys), two schema rules, config.py cross-checks | V, U (config tests) |
| refactor: card text takes one face object | `SplitText`/`CardAction` take `face: {item, ink, wash}`; origins mapped | V (artifacts, session-ui; screenshot: wash ink split intact) |
| remove: CardKinds.js and ArtifactCard's plain-paper path | inline routing; `decorated`, insets, `dimensions.inset` | V |
| style: card kinds pass qmllint | | U (qmllint) |

Found: a directory imported by path needs a `qmldir`. Without one, `kinds/` resolved when
`shell.qml` was the root file and was "not a type" when `shell.qml` came through a Loader
(single-config). `tests/qml-static.test.cjs` now checks every path-imported directory.
`print` is an illegal QML property name.

### Size, Phases 1.7–3

QML/JS/Python/CJS lines (excluding the generated `defaults.js`), from the imported Phase 1
tree to now: quickshell 7470 → 7631, lib 1471 → 1462, tests 3367 → 3562, scripts 972 → 972.
The shell grew by 161 lines: the card split adds file headers and an adapter interface
(ServiceCard 555 → 133, `kinds/` +~560), and SplitText's origin tracking replaced arithmetic
at call sites. The runtime cost went down (one adapter per card, no UPower per card, no
recreated delegates, fewer forks); line count is not the measure for Phase 3. Config keys:
−48 (`cards.*` behaviour), −1 (`dimensions.inset`).

Git: this repository's `main` holds Phase 1 as one import commit. The archive's own `.git`
has one commit per Phase 1 task (`5137877` baseline … `5f1a26f`); fetch it from the
archive if you want that history.

## Phase 5, step 1: measurements (before)

`ILLUMINATED_PROFILE=1` logs every Canvas paint; `tests/runtime/profile.py` drives the
production shell (software renderer, this 4-vCPU container: relative numbers only):

| Step | GUI responsive after | Canvas paint time | Paints |
| --- | --- | --- | --- |
| startup (to first IPC answer) | 449 ms | 2187 ms in the next 3 s (Vellum 1843) | 22 |
| first launcher open | 8639 ms | 8516 ms (SkinElement 6353, Vellum 2055) | 13 |
| first hand deal | 3246 ms | 701 ms (MaterialFace 665) | 7 |
| 2 s volume drag (20 IPC steps) | 19529 ms wall | 8291 ms (SkinElement 6315, MaterialFace 1827) | 34 |

Canvas items alive: 11 at idle with one output, 16 with a hand out. The first material-image
decode (`MaterialFields.ensure`) costs about 680 ms inside whichever canvas paints first, and
then every canvas repaints. Skin elements repaint on every volume change (the vial shows the
level), at about 400 ms each.

Foundation hypothesis (V7.md "Still open"): the launcher-reopen failure fails the same way
with `features.wallpaper = false` and with `features.rail = false` (two runs each). In the log
the launcher surface is destroyed about 3–6 s after Escape was sent, so the second
`illuminated launcher` (a toggle) arrives while the first is still open. The failure tracks
first-paint time of the launcher's own vellum and the material decode, not the rail.

## Inspiron checklist (L)

Grows with each phase. From Phase 1:

1. `illuminated apply --check` against your own `config.toml`: it now rejects any key in the
   CHANGELOG's "Removed keys" table. Move those settings to their replacements.
2. Rail clock shows the time in `clock.timeFormat` (default `hh:mm`); the lock screen too.
3. Herbarium sheet → "Align cards to grid" deals untilted cards; "Tilt cards" restores 4°.
4. `illuminated cards levels` deals the Levels hand from the rail; `illuminated hide`
   dismisses it and also closes an open launcher.
5. Sleep and Shut Down confirmations still cancel after 5 s (15 s under Accessibility).
6. Dock and workspaces under title churn: open a terminal on workspace 1 and one on 2, run
   `for i in $(seq 50); do printf '\033]0;t%s\007' $i; sleep .1; done` in one. Expected: the
   dock icons and rail numerals do not flicker or lose hover/focus.
7. Dock focus/move: click a dock icon on another workspace (switches there); Shift-click two
   icons and release Shift (both come to the current workspace).
8. Hyprland reconnect: `hyprctl reload`, then switch workspaces. Expected: the rail follows.
   If it does after a full compositor restart too, the health socket is redundant (report).
9. Brightness: press the brightness keys (handled by Hyprland binds) with a Levels hand out.
   Expected: the Light card follows within 3 s; `pgrep -c brightnessctl` stays 0 at idle.
10. A dock skin element that deals a hand (example skin): the hand comes in from the left at
    the dock's height, under a permanent dock.
11. Cards: Sound, Light, Battery, Wi-Fi, Bluetooth, Sleep, Shut Down behave as before (click,
    drag, dog-ear, backs). Battery's back shows Profile, Remaining and Limit on the laptop.
