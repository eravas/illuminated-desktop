# Status

This is the single record of what has been verified, and how. It replaces the deleted
NEXT-SESSION, HARDENING, RUNTIME-REPORT, CARD-HARDENING-V2, CONFIG-V3, DEVELOPMENT-REPORT
and VALIDATION reports. The plan is in [SIMPLIFICATION-HANDOFF.md](../SIMPLIFICATION-HANDOFF.md).

Labels: **V** verified at runtime (headless Sway, Quickshell); **U** unit or static checks
only; **L** needs local acceptance on the Inspiron (Hyprland).

## Baseline: v7-dev as received (commit `5137877`)

- Node tests 166/166, Python unittest 80/80, `illuminated apply --check` valid. Run in the
  Claude session that did Phase 1.
- Runtime suites, from the 2026-11-02 runtime report (Quickshell 0.3.2, Qt 6.12, headless
  Sway, software rendering):
  - pass: artifacts, smoke, audio, reload, greeter, single-config, session-ui;
  - **foundation**: the launcher reopen / launch-marker steps fail intermittently (not
    diagnosed; see V7.md "Still open");
  - qmllint: non-strict warnings (Quickshell type-metadata gaps).

## Phase 0: repository (done)

The tree is a Git repository. `checkpoints/` (30 MB: history bundles and the foundation
tarball) and `artifacts/` (4.9 MB of test logs) are not committed; the original tarball
keeps them. The compositor include evidence moved to `docs/evidence/compositor-includes/`.

## Phase 1: deletions (done; runtime suites not yet run)

Done in a Claude session **without Qt, Quickshell or qmllint**: no Qt runtime was available
and the package index refused the PySide6 download. What was checked there:

- Node tests (153/153; the 13 fewer are the per-file QML structure checks of deleted files);
- Python unittest (78/78);
- `illuminated apply --check`;
- both skin build scripts (images byte-identical to the committed skin after the
  `Materials.js` move);
- the Chromium visual harness, which still renders every contact sheet.

Everything touching QML or the runtime suites is therefore **U** until `dev/test-all.sh`
runs.

| Commit | Change | Label |
| --- | --- | --- |
| remove: v6 top bar | bar UI, `[bar]`, `[bar.opens]`, `features.bar`, `dimensions.barHeight`, bar validation; `bar.timeFormat` moved to `clock.timeFormat` (rail clock, lock screen) | U |
| remove: Controls diagnostic window | Controls, Audio, Network tools; `controls` CLI/IPC/bind; CommandAction moved to `services/`; the foundation suite's show/hide probes rewritten to use a hand and the launcher | U (runtime test edits not run) |
| remove: v2 migration | `illuminated migrate` and its TOML writer | U (Python) |
| remove: v6 compatibility shims | highLegibility, battery.lowChargeNumeral, deck.rotation/aligned, confirm.timeout; Herbarium align toggle now sets `reading.options.rotation` | U |
| move: Materials.js facade | to `scripts/skin/` | U (Node, skin build, harness) |
| remove: five reading options | disabled, focusRing, overflow, stateText, stickySelect | U |
| remove: dead timer and unused functions | NotificationHub 2 Hz timer; four functions | U |
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

## Inspiron checklist (L)

Grows with each phase. From Phase 1:

1. `illuminated apply --check` against your own `config.toml`: it now rejects any key in the
   CHANGELOG's "Removed keys" table. Move those settings to their replacements.
2. Rail clock shows the time in `clock.timeFormat` (default `hh:mm`); the lock screen too.
3. Herbarium sheet → "Align cards to grid" deals untilted cards; "Tilt cards" restores 4°.
4. `illuminated cards levels` deals the Levels hand from the rail; `illuminated hide`
   dismisses it and also closes an open launcher.
5. Sleep and Shut Down confirmations still cancel after 5 s (15 s under Accessibility).
