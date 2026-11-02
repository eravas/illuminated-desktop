# Handoff: simplify The Illuminated Desktop (v7-dev)

Audience: Codex, working unattended in an Arch cloud environment that runs **headless Sway**
(no Hyprland, no Mango renderer). Source: this repository. **Phases 0 and 1 are done**; see
`docs/STATUS.md` for what was and wasn't verified. Start with *Phase 1 verification* below.

## Goal

The project has been refactored several times. Each version left its predecessor partly
wired in, and the rendering and skin layers do in JavaScript what Qt Quick already does
natively. Make it **smaller and cheaper at runtime without changing what the user sees or
can do**, except where this document lists a removal.

This is a simplification pass, not a redesign. Do not change the visual language, the
interaction contract (`docs/FEATURES.md` § Interaction contract, minus the bar), the
config file location, or the compositor adapter boundary.

## What this environment can and cannot prove

| Area | How it runs here | Label |
| --- | --- | --- |
| QML loads, bindings, IPC, cards, sheets, launcher, rail, dock layout | headless Sway (`dev/headless.sh`, `WLR_RENDERER=pixman`), `QT_QUICK_BACKEND=software` | **V** (verified at runtime) |
| Audio | private PipeWire/WirePlumber with virtual nodes (`dev/audio-session.sh`) | V |
| Mango adapter | real `mmsg` against `tests/runtime/mango-fixture.py` | V (fixture) |
| Hyprland adapter, Lua dispatch, `special:minimized`, reservations under Hyprland | cannot run | **U** (unit only) / **L** (local acceptance) |
| NetworkManager, BlueZ, UPower, logind, polkit, backlight | absent | U / L |
| GPU shader effects (`ShaderEffect`, `MultiEffect`) | the software backend does not render them | L |
| Real performance numbers | software renderer only, not representative | L (relative timings are still useful) |

Label every change in your report **V**, **U** or **L**. Anything that is L goes on the
Inspiron checklist (see *Reporting*). Never describe an L item as verified.

Consequence for design choices: **do not introduce `ShaderEffect` or new `MultiEffect` uses.**
Anything you build must render under `QT_QUICK_BACKEND=software` so the runtime suites keep
covering it. (`materials/Loupe.qml:40` already uses `MultiEffect`; check the Sway logs to see
whether it renders there. Leave it as is.)

## Ground rules

- One commit per task, using a conventional subject (`remove: top deck origin`,
  `perf: stable dock model`). One branch per phase. The repository's existing commits show
  the style.
- Keep `bash scripts/validate.sh` and `bash dev/run-vfs.sh bash dev/test-all.sh` (or
  `dev/run.sh`) green after every phase. If a suite was already failing at baseline, say so
  and don't let it get worse. The `foundation` suite's launcher reopen step is a **known
  intermittent failure**. See Phase 5, step 1.
- When you delete a feature, delete its tests, docs, config keys, schema rules, `doctor`
  checks and `illuminated isolate` entries in the same commit. Leave no dangling references:
  `grep` for the names before you commit.
- `illuminated apply` rejects unknown keys (`lib/illuminated/config.py:188`). Every config key
  you remove must be listed in `CHANGELOG.md` under "Removed keys", with its replacement if
  there is one.
- Add no new runtime dependencies. Node is already used by the skin build and is optional
  for `doctor`. If Phase 5 makes it required for `apply`, that is decision D2 below.
- Never run the installer against a real home. Tests already use throwaway homes.
- Don't touch: the greeter (`greeter.qml`, `greeter/`), `integration/`, the Mango
  adapter's protocol logic, the RemovableMedia event-then-snapshot design, or the pure logic
  modules' behaviour (`Geometry.js`, `CardModel.js`, `MediaLogic.js`, `WindowLogic.js`,
  `MangoLogic.js`). You may move them.
- If something in this document turns out to be wrong when you read the code, don't force it.
  Write down what you found, skip the task and continue.

## Decisions the user may answer later (use the default if they haven't)

- **D1. Skin format. Decided by the user: QML skins.** A skin is a directory of QML
  components loaded by the shell; `skin.json` keeps only plain asset data. The user will
  share the project but expects to be its only user, so a skin is trusted code like the rest
  of the rice. Phase 6 is required; see it for the design.
- **D2. Where material textures are baked.** (a) `illuminated apply` bakes them with Node into
  `~/.config/illuminated/generated/` for every palette in config, at grain 1 and 2. Node
  becomes required for `apply`. (b) Palette-independent texture overlays (luminance/alpha
  grain) are committed to the repo and coloured at display time by stacking them over a
  palette `Rectangle`. This only works if the look survives; the Phase 5 spike decides.
  **Default: run the spike, prefer (b) if the screenshots are acceptable, otherwise (a).**
- **D3. Shell lock screen.** Keep `features.lock`. Simplify how it is driven (Phase 7).
  **Default: keep it.**

---

## Phases 0 and 1: done (by Claude, without a Qt runtime)

`git log` shows one commit per task. `docs/STATUS.md` lists each one with its label, the
deferred items and why, and the line, file and config-key deltas. `CHANGELOG.md` has the
"Removed keys" table. Summary:

- the v6 top bar (`bar.timeFormat` moved to `clock.timeFormat`);
- the Controls diagnostic window (CommandAction moved to `services/`);
- `illuminated migrate`;
- the v6 shims (highLegibility, battery.lowChargeNumeral, deck.rotation/aligned,
  confirm.timeout);
- five unimplemented reading options;
- the NotificationHub dead timer and four unused functions;
- the `Materials.js` facade moved to `scripts/skin/`;
- superseded docs.

Node and Python tests, `apply --check`, the skin build and the Chromium harness were run
there. **No QML was loaded and no runtime suite was run.**

### Phase 1 verification (do this first)

1. `bash scripts/validate.sh` (it now has qmllint), then `bash dev/run-vfs.sh bash dev/test-all.sh`
   (or `dev/run.sh`).
2. Fix anything the Phase 1 edits broke. The likeliest places are:
   - `tests/runtime/run.py` `shell()`: the Controls probes became
     `illuminated cards levels` / `hide` with `status.artifacts`, and `launcher` / `hide` with
     `status.launcherOpen`;
   - its disabled-feature loop, which now checks `Cards` via the `illuminated-cards`
     namespace;
   - `features.qml`, `smoke.py` and `single-config.py` (`rail.hands`,
     `dimensions.controlHeight`);
   - `services/CommandAction.qml` resolving from `MangoAdapter.qml`, `BrightnessState.qml`,
     `SessionState.qml` and `tests/runtime/commands.qml`.
3. Update the baseline table in `docs/STATUS.md` with real results and turn the Phase 1 U
   labels into V where a suite now covers them. The `foundation` intermittent failure
   predates Phase 1; record whether it still occurs.

### Phase 1.7: deferred deletions (V)

- **The `origin: "top"` deck path.** Remove `Navigation.origin`/`triggerX` and the top
  fallback (hands always come from the left; with the rail off, `chromeLeft` is 0 and the lane
  is the screen's vertical centre). Also remove the `fromLeft` branches in `CardsLayer.qml`,
  `Geometry.deck` and its unit tests.
  - Rewrite `tests/runtime/artifacts.py`, whose `group()` IPC opens top-origin decks and
    asserts card centres on an x-lane and pagination at 320×240.
  - Rewrite `tests/runtime/artifacts.qml` (`group()`) and `tests/runtime/audio.qml`
    (`Navigation.open("sound", …, "top")`) so they use `hand()`/left-origin assertions from
    `Geometry.dealLeft`.
  - Keep each original assertion's intent: separation, pagination without inaccessible
    cards, flip and selection.
- **Groups `light` and `session`** (they duplicate `levels`/`battery` and `power`). Repoint
  the `artifacts` suite and `tests/test_config.py` to `levels`, `battery` and `power`. Keep
  `sound` and `media`: they are the only decks holding the microphone, Devices and Music cards.
- Acceptance: all suites at baseline or better;
  `grep -rn 'origin === "top"\|triggerX\|Geometry.deck' quickshell tests` is empty.

## Phase 2: stable models and idle wakeups

**2.1 The dock rebuilds every delegate on any window title change (V via Mango fixture).**
`rail/Dock.qml:89` uses `Repeater { model: root.windows }`. `DesktopState.windows` is a fresh
array built by `WindowLogic.hyprlandWindows/mangoWindows`, which read every toplevel's title,
so any title change resets the Repeater and recreates every `DockEntry`.
- Hyprland: build the model from the native `HyprlandToplevel` QObjects, using
  `ScriptModel { values: Hyprland.toplevels.values.filter(...) }`. QObjects compare by
  identity, so delegates survive. Delegates read live properties (`title`, `workspace`,
  `wayland.appId`) and derive `minimized`/`focused` themselves, using the existing pure
  helpers in `WindowLogic.js` so the unit tests still apply. Label: U + L.
- Mango: entries are plain JS from `mmsg`. Use `ScriptModel` with `objectProp: "id"`.
  Matching by `objectProp` keeps the *old* object, so delegates must look up their live
  entry by id (for example `DesktopState.windowById(id)`) rather than trust `modelData`
  fields. Check the Quickshell 0.3.2 `ScriptModel` docs for the exact semantics.
- Keep the adapter contract. `DesktopState` may expose a model plus a lookup instead of a
  plain array.
- Test: extend `tests/runtime/compositor.py` / `compositor.qml`. With the Mango fixture, push
  a title change for one client and assert that the dock delegates for the other clients
  were not recreated (count `Component.onCompleted` per delegate via an `objectName`ed
  counter) and that the changed title is shown.

**2.2 Rail workspaces have the same problem (V via Mango fixture, Hyprland U/L).**
`RailWorkspaces.qml:27` binds to `context.spaces`.
`adapter.context()` returns `spaces`, `selection` and `title` in one object, so a title
change rebuilds the spaces. Split `title` out of `context()`, either as a separate
`DesktopState.title(outputName)` or a separate binding, and wrap `spaces` in `ScriptModel`
keyed by the workspace or tag `id`. `title` was only shown by the bar. If nothing else uses
it after Phase 1, delete it.

**2.3 Brightness polling (U/L: no backlight here).** `services/BrightnessState.qml:34` runs
`brightnessctl` every 3 s whenever the OSD is enabled, which is a fork and exec each time.
Replace the poll's *read* with a `FileView` on
`/sys/class/backlight/<device>/actual_brightness` and `max_brightness`, reloaded on the
timer, or on `udevadm monitor --subsystem-match=backlight` events if you can multiplex the
existing monitor in `services/RemovableMedia.qml` cleanly. Writes stay `brightnessctl`
(permissions). The device comes from `hardware.backlightDevice`, otherwise the first entry
in `/sys/class/backlight`. Keep the missing-device error path and its runtime test.

**2.4 Hyprland adapter reconnect machinery (U/L).** `compositors/HyprlandAdapter.qml` has:
- a `Socket` to the event socket used only as a health flag;
- a 2 s reconnect timer (line 74);
- a 10 s `reconcile()` issuing three refresh requests forever (line 75);
- a 250 ms settle loop (40 tries);
- a one-shot `hyprctl -j activeworkspace` seed.

Keep the settle loop and the seed: they fix an observed startup gap. Remove the unconditional
10 s reconcile, and reconcile on reconnect only. Do **not** remove the health socket without
evidence: you can't test Hyprland here. Put "does Quickshell's own Hyprland connection
reconnect after a compositor restart, making the health socket redundant?" on the L
checklist. Leave Mango's timers alone (stream-based IPC).

## Phase 3: ServiceCard and card plumbing (V)

**3.1 Replace `switch (kind)` with per-kind adapters.** `artifacts/ServiceCard.qml` (555
lines) branches on `kind` in about ten places: lines 40–46, 58, 136–170 and 253–256 (level
value, presentation, `onActivated`, drag start, adjust, step, `onCompleted`, `hasBack`, back
selection, `detail`). Every instance also binds UPower, PowerProfiles and a sysfs
`FileView`, even the volume card.
- Introduce one small adapter per kind, either QML objects or JS objects in a
  `cards/kinds/` registry. Each provides `level`, `setLevel(v)`, `step(d)`, `activate()`,
  `presentation(colours)`, `back` (a `Component` or null) and `onOpen()`. `ServiceCard`
  keeps flip, selection, gesture, face and chin layout, and delegates the rest.
- The battery details (`laptopBattery`, `chargeLimit` FileView, `remainingText`, profile
  text) move into the battery adapter, so only the battery card instantiates them.
- Behaviour must not change: the `artifacts`, `audio` and `session-ui` suites are the
  acceptance tests, unmodified except for object paths.

**3.2 Stop exposing behaviour as config.** `[cards.*].interaction` and `orientation` look
configurable, but behaviour is keyed on `kind`. For example, setting
`cards.volume.interaction = "toggle"` turns clicks into flips. Move `interaction`,
`orientation` and `alternatives` into the adapters. Keep `title`, `short`, `sheet` and
`confirm` in config. Update `defaults.toml` (most of the 101 `cards.*` keys go), schema,
`config.py` cross-checks, `Registry.js` skin cards (they still need orientation, which a
skin card can declare), CHANGELOG and `CONFIGURATION.md`.

**3.3 Text plumbing.** `SplitText` and `CardAction` receive the same props (`ink`, `wash`,
`faceWidth`, `faceHeight`, `originX`, `originY`, `family`, `pixelSize`) about 25 times, with
origins summed by hand (`originX: stats.x + stat.x + x`). Give them a single `face` object
(`{ink, wash, width, height, family}`) and compute the origin with
`mapToItem(faceItem, 0, 0)` when the wash or geometry changes. Keep the two-clipped-copies
technique.

**3.4 Small indirections.** Inline `artifacts/CardKinds.js` (12 lines, one prefix) into
`CardsLayer.qml`. Remove `ArtifactCard`'s `decorated`/`frontInset`/`backInset`/`Paper` if,
after Phase 1, every card sets `decorated: false`. Today all three card types do; only the
greeter uses `Paper` directly.

## Phase 4: settings layer (V)

- `config/Settings.qml` has about 80 alias properties, many with one consumer, and
  `theme/Theme.qml` re-aliases some again. There are four access styles: `Settings.foo`,
  `Settings.option("a.b")`, `Theme.foo` and `Settings.reading.foo`. Target: raw config through
  `Settings.option(key)` (it already participates in bindings), **derived** values (anything
  computed from several keys or the reading preset) on `Theme`/`Motion`, and nothing else.
  Keep a named property only where it is derived or used in more than about three places.
  Mechanical. Do it file by file and keep suites green.
- The enum lists live in both `defaults.toml` `schema.rules` and `Reading.js` `OPTIONS`.
  Generate `Reading.js`'s option lists (or a small `reading-options.js`) from the TOML in
  `illuminated defaults --write-json`, as `defaults.js` already is, so there is one source.
  Presets may stay in `Reading.js`.
- Move the `mkdir -p` `Process` in `Settings.qml` and the `sh -c` directory bootstrap in
  `NotificationHub.qml` into `illuminated apply`/`install`, which already create
  `~/.config/illuminated/generated/`, if that keeps the "first start without apply" path
  working. Otherwise leave them and say why.

## Phase 5: rendering, from per-pixel JavaScript to baked textures and native items

This is the largest change. Do it surface by surface, behind no flags, one commit each.

**Why.** Every material surface is a `RasterCanvas` (`Canvas.Image`, painted on the GUI
thread) filled pixel by pixel in JS:
- `Vellum` (rail, dock, sheets, launcher);
- every `SkinElement`, composited in `Compose.js`/`ArtLayers.js` (alpha-over, ink fill,
  quantise, blurred shadow);
- card faces (`MaterialFace` → `CardPaint`/`CardFace`), repainted whole at up to ~30 Hz while
  a level is dragged;
- `FocusHalo`, a new canvas created by a `Loader` on every focus change, on every card and
  `ActionButton`;
- devices and initials.

On top of that, `MaterialFields.qml` decodes `vellum.png` (1024²) and `patina.png` (512²)
through `getImageData` with element-wise copies (`CanvasPixelArray` is not a typed array)
inside whichever canvas paints first. Every material also keeps a procedural fallback
(`Fields.tex`, `CardFace.sheen`, `copperAt`).

The device-pixel-exact dither, which is the reason for Canvas, is lost on cards anyway: they
are rotated ±4° (`ArtifactCard.qml:66`) and the canvas uses `smooth: false`
(`RasterCanvas.qml:40`), so rotation resamples the dither with nearest-neighbour.

**Steps**

1. **Measure first (V, relative).** Instrument `RasterCanvas` `onPaint` with
   `console.time`/`console.timeEnd` keyed by `objectName`, and log `MaterialFields.ensure`
   duration. Record:
   - startup (shell to first rail frame);
   - first launcher open;
   - first hand deal;
   - a 2-second volume drag.

   Then test the foundation-suite hypothesis from `docs/V7.md` ("Still open"): rerun the
   foundation suite with `features.wallpaper = false`, then `features.rail = false`, and
   report whether the intermittent launcher reopen failure tracks first-paint time. Put the
   numbers in `docs/STATUS.md`. They are the before-numbers for every later step.
2. **Spike for D2 (V, screenshots).** For the rail `Vellum` only, build both candidates:
   - (b) a palette `Rectangle` plus a committed greyscale/alpha grain texture (`Image`,
     `fillMode: Image.Tile`, `smooth: false`), with the fray as a `BorderImage` edge;
   - (a) a Node bake of the current `VellumPaint.paintVellum` output per palette at grain 1
     and 2, written by `illuminated apply`.

   Capture both next to the current Canvas output with `grim` (see `capture()` in
   `tests/runtime/run.py`) in light and dark mode, and build a contact sheet. Pick per D2's
   default rule and record why. Don't pixel-diff: dither placement legitimately differs.
3. **FocusHalo → `BorderImage`.** A rounded-rect halo is a nine-slice: corners plus edges
   tiled with `BorderImage.Repeat` so the dither tiles instead of stretching. One baked image
   per style (`halo`/`thick`/`solid`) and mode. Remove `Halo.js` from the shell, keeping the
   painter for the bake.
4. **Vellum** (rail, dock, sheets, launcher) per the spike result. Keep `offX`/`offY`
   continuity if the tiled texture allows (tile origin = screen position); otherwise note
   the regression for the user.
5. **Card faces.** Split each face into a static base (baked or composed from images) and a
   live **level layer**: a clipped `Item` whose width or height binds to the level, holding
   the fill texture, plus a small pre-baked dither-edge strip positioned at the level mark.
   Dragging must run no JS per frame beyond bindings.
   - Foil sheen that strengthens with level (`CardFace.sheenAmp`) becomes an opacity-blended
     sheen layer (`opacity` bound to the level curve).
   - Patina stages become pre-baked images per stage.
   - The low-charge numeral halo becomes a pre-baked image or text with a baked glow image.
   - Card art from the skin (`cardArt`) becomes a plain `Image` with
     `fillMode: Image.PreserveAspectCrop`, `horizontalAlignment`/`verticalAlignment` from
     `focus`, and luminance/saturation through an overlay `Rectangle`. If saturation can't be
     reproduced without a shader, note it and keep luminance only.
6. **Skin elements: done in Phase 6** (D1 = QML skins). Don't build a native renderer for
   the current `skin.json` element format. Order: Phase 5 steps 1–5, then Phase 6, then
   Phase 5 steps 7–9.
7. **Remove the decode path.** `MaterialFields.qml`, `Fields.setField`/`FIELDS`, the
   procedural fallbacks in the shell, and `ArtLayers.rasterise`, once nothing needs them.
   The procedural painters stay in `scripts/skin/painters/` as the bake source.
8. **Tests.** The Chromium Context2D stand-in (`tests/visual/qml-context2d.js`,
   `render.cjs`, `load.cjs`) only exists to validate Canvas painters. Keep it as long as the
   bake uses the painters (it tests the bake), and drop QML-specific assertions that no
   longer apply. Replace `tests/qml-structure.test.cjs` (a hand-written QML tokenizer and
   type whitelist) with the qmllint step already in `validate.sh` plus the runtime load
   checks, if qmllint in this environment catches the same classes (unknown type, missing
   import). Verify by introducing one deliberate typo of each class. Keep
   `qml-static.test.cjs` checks that encode real Quickshell pitfalls (the Loader
   implicit-size rule).
9. **After-numbers.** Repeat step 1's measurements and record the delta. Report "Canvas
   instances alive at idle with one output", before and after.

**Reactivity hazard (fix in Phase 6).** `skin/Registry.js`,
`DeviceGeometry.registerArt`, `DeviceArt.setImages` and `Fields.FIELDS` are mutable globals
in `.pragma library` modules. Bindings that read them (for example
`Settings.card("skin:x")`) don't re-evaluate when the skin loads. There are three separate
invalidation counters (`SkinStore.version`, `MaterialFields.version`,
`Fields.fieldsVersion()`). Move skin-derived registries onto `SkinStore` (a QML singleton,
so reactive) and have `Settings.card/group` read them from there. This also removes the
`config/ → skin/` import inversion.

## Phase 6: QML skins (V, required)

Replace the data-driven skin engine with skins written in QML. What the user sees must not
change: the default skin's rail and dock objects look and behave as today (tags, triggers,
scroll steps, hover animations, ink levels, charging bands), apart from the dither and
shadow now being baked.

### Shape of a skin

```
skin/
  skin.json        # data only: name, about, devices, materials, loupes, cardArt, pins
  Rail.qml         # optional: the rail's layout
  DockChrome.qml   # optional: dock elements before/after the windows
  Vial.qml …       # element components, used by Rail.qml / DockChrome.qml
  Cards.qml        # optional: skin cards and hands (replaces skin.json "cards"/"hands")
  *.png, *@2x.png  # images; Qt picks @2x automatically when devicePixelRatio > 1
```

**Overlay by file, not by key.** For each QML file name, the user's skin directory wins if it
has that file; otherwise the default skin's file is used. This replaces
`Skin.merge`/`absolutise` for QML. `skin.json` data may still merge key by key (it is small
and plain), or switch to the same per-file rule. Pick one and document it.

**`Rail.qml` composes shell-provided pieces** with the skin's own elements, which replaces the
`rail.items` list:

```qml
RailLayout {                         // shell type: a Column that knows the rail's width and pxmm
    Vial { hand: "levels" }          // skin element
    RailRule {}                      // shell types from here down
    RailWorkspaces {}
    RailHands {}                     // hands listed in rail.hands that no element deals
    RailSpacer {}
    MediaBay {}
    RailClock {}
    foot: Paper {}                   // the corner element
}
```

`DockChrome.qml` has `before`/`after` slots in the same way. If the skin has no `Rail.qml`, the
default skin's is used.

### Shell API for skins (one `qmldir` module, for example `import Illuminated.Skin`)

- **`SkinItem`**, the base for elements:
  - `mm(x)` for life-size units (from `DeviceGeometry.pxPerMm`) and `px(x)`;
  - `hovered`, `pressed`, and `clicked(button)`, `wheelStep(direction)`, `doubleClicked()`
    signals;
  - `tag` (hover text, shown in the shared `Tag`);
  - `hitShape`: rect, circle or polygon objects implementing `contains(point)`, wired to
    `containmentMask`. Polygons replace alpha-mask hits; give thin objects like the nib and
    paperclip a polygon in the default skin.
  - Keyboard: Tab, Enter and Space trigger `clicked`, with an accessible name from `tag`.
- **`ShellState`** becomes a singleton with **typed properties** (`volume`, `muted`,
  `batteryLevel`, `batteryState`, `networkStage`, `unread`, …) instead of the flat
  string-keyed `values` map. Keep the same names in camelCase, list them in SKINS.md, and
  delete the `values` object.
- **`Actions.run(name, ctx)`** stays, along with `available()` and `label()`. `command:<name>`
  stays as a convenience for user-defined commands in `[commands.custom]`. It is **no longer a
  security boundary**: say so in SKINS.md.
- **`InkFill`**, for an ink level inside an object's mask: `level`, `frames` (a pre-baked
  sheet of masked ink at N steps, for example 24, made at skin-build time), `bands` (a
  pre-baked canary overlay shown when true). It picks a frame with `sourceClipRect`; no
  per-pixel work at runtime.
- **`Marker`** (dot or ring), reproducing `Compose.marker`, as a small baked image or
  `Rectangle`s.

Animation, states and templates are plain QML (`Behavior`, `State`, `AnimatedSprite`,
bindings). No skin DSL remains.

### Default skin

- `scripts/skin/build-default.cjs` keeps generating the images, but now also bakes:
  - the finish (7-level dither and drop shadow from `Compose.finish`/`ArtLayers.finish`) into
    each element image, at 1× and @2x;
  - the `InkFill` frame sheets and band overlays.
- Hand-write the default skin's QML from the current `skin.json` elements (`tray`, `nib`,
  `vial`, `antenna`, `converter`, `matchbox`, `paper`), mapping each `states`, `triggers`,
  `animations`, `tag` and `hit` entry. Keep a mapping table in the commit message.
- Port `skins/example/` (tray on the paper, wax seal dealing a new hand with a new card, a
  dock button, hover animations) as the proof that the API covers what the old format did.

### Delete

- `skin/Compose.js` and `skin/SkinElement.qml`;
- from `skin/Skin.js`: conditions, look selection, frames, templates, animation, hit maths,
  actions parsing (moved into `Actions.qml`) and `check`. Keep only what still serves
  `skin.json` data, if anything;
- `scripts/skin/check.cjs` and the `doctor` call to it. Replace it with a load check:
  `illuminated doctor` runs qmllint over the user's skin directory when qmllint is installed;
- the skin-format tests in `tests/skin.test.cjs`, replaced by the runtime tests below.

`docs/SKINS.md` is rewritten for the QML API. Keep it short: layout, overlay rule,
`SkinItem`, `ShellState` properties, actions, `InkFill`, and asset conventions (@2x,
baking).

### Old-format skins

If `~/.config/illuminated/skin/skin.json` contains `elements`, `rail.items` or `dock.before`
or `dock.after`, `illuminated apply` and `doctor` warn that the skin uses the old format and
is ignored. The shell falls back to the default skin rather than failing.

### Tests (V)

Add a runtime suite (or extend `artifacts.py`) that:
- loads the default skin and asserts every rail element is present by `objectName`;
- with a virtual pointer, clicks the vial (a Levels hand deals), scrolls it (volume changes
  under PipeWire virtual nodes), and hovers it (tag text);
- loads `skins/example` via `skin.path` and asserts the wax seal deals its hand and its skin
  card renders;
- puts a user override of one file (for example `Vial.qml`) in a temporary skin directory
  and asserts it replaces only that element;
- checks that an old-format `skin.json` warns and falls back.

## Phase 7: lock and suspend (mixed V/L)

1. **In-process lock (V where possible).** The Sleep card runs `commands.lock`. With the shell
   lock that is `illuminated lock` (Python, `lib/illuminated/cli.py:49`), which calls
   `quickshell ipc call lock`, polls `ipc call status` every 100 ms by spawning a new process
   each time, and then SessionState runs suspend. When `features.lock` is on, `SessionState`
   should lock through the lock feature directly and run the suspend command when the lock
   reports `secure`, with the same timeout and fallback rules. Keep `illuminated lock` for
   external callers (keybinds, idle daemons). Sway supports ext-session-lock, so test the
   in-process path in `session-ui` with the marker-substitute suspend command.
2. **Logind delay inhibitor (L).** Today "never suspend an unlocked session" holds only for
   the Sleep card. Lid close, idle suspend, the power key and `systemctl suspend` bypass it.
   Don't implement a logind client here; you can't test it. Instead write a short design note
   in `docs/STATUS.md` comparing:
   - hypridle `before_sleep_cmd` plus `inhibit_sleep` (check the option values for the
     user's hypridle version: <https://wiki.hypr.land/Hypr-Ecosystem/hypridle/>);
   - the shell holding `systemd-inhibit --what=sleep --mode=delay` and locking on
     `PrepareForSleep`.

   Give a recommendation, and list which of `commands.lockReturnsWhenReady`, `lock.fallback`,
   `lock.timeout` and the "Sleep refuses" branch would become removable.

## Out of scope

The greeter; polkit agent behaviour; NetworkManager/BlueZ flows; the installer's
snapshot/restore machinery (optional trimming, low priority, untouched unless everything
else is done); new features; visual redesign; Hyprland dispatch template changes.

## Reporting

Keep `docs/STATUS.md` (it already holds the baseline, Phase 0–1 and the start of the
checklist) current with:
- baseline and current suite results and lint exit;
- per phase: commits, line-count delta, V/U/L label per change, anything skipped and why;
- performance before/after (Phase 5);
- decisions D1–D3 as applied;
- **Inspiron checklist**: every L item as a concrete step the user can run on Hyprland
  (command, expected result). It must include at least:
  - dock and workspace delegates surviving title churn (open a terminal, run commands that
    change the title, watch for flicker);
  - the dock's focus/move dispatch;
  - Hyprland reconnect after a compositor restart (is the health socket needed?);
  - brightness reads from sysfs and external changes picked up;
  - Loupe `MultiEffect` rendering;
  - grain crispness at 1× and 1.25×;
  - card rotation appearance with baked faces;
  - QML skin elements at life size, with @2x assets picked at 1.25× and 2×, and
    polygon hit areas on the nib and paperclip;
  - first-open timings of the launcher and a hand;
  - the lock in-process path with a real PAM login.

Update `CHANGELOG.md` with user-visible changes and the "Removed keys" list.
