# Skins

Everything you see on the rail and dock, the removable media, card art, launcher pins and the
material textures comes from a **skin**: a `skin.json` plus image files and sprite sheets. The
shell itself draws no objects. It loads your images, composites them, applies the dither and
shadow, and runs the buttons you define.

Skins are meant for people who want to change things beyond `config.toml`. They are
deliberately outside the one-config rule. `config.toml` still decides *what the shell does*:
which hands exist, which features are on, colours, reading options, named commands. The skin
decides *what it looks like* and *where the buttons are*.

- **The default skin** is `quickshell/skins/default/`. It is generated from the old drawings by
  `node scripts/skin/build-materials.cjs` then `node scripts/skin/build-default.cjs`.
- **Your skin** is `~/.config/illuminated/skin/` (or `[skin] path`). Its `skin.json` is laid
  over the default key by key:
  - objects merge;
  - arrays replace;
  - `null` removes a key.

  So you only write what you change. File paths are relative to the skin they appear in; reach
  the default's images with `../default/…` only if you copied the default next to yours,
  otherwise copy the images you need.
- **The worked example** is `quickshell/skins/example/`: copy it to
  `~/.config/illuminated/skin/` to try it. It moves the tray onto the paper, adds a wax seal
  that deals a new hand with a new card, a dock button, and hover animations.
- **Reloading:** the shell watches both `skin.json` files. Replace images first, then save
  `skin.json`; every image URL changes with the skin's version, so new images load.
- **Checking:** `illuminated doctor` parses your skin and lists missing images and unknown
  commands. The shell logs `illuminated skin: …` for anything it drops.

## Units

`units` is `"mm"` (life size: scaled by the output's physical px/mm, like the removable media)
or `"px"` (logical px). It is set skin-wide and can be overridden per element. Sizes, anchors,
rects and points are in these units, measured from the element's top-left.

## Images and sheets

```json
"sheets": { "antenna": { "file": "rail/antenna-sheet.png", "columns": 6 } },
"images": {
  "nib": "rail/nib.png",
  "vial.ink": { "file": "rail/vial-ink.png" },
  "cell": { "sheet": "antenna", "rect": [0, 0, 170, 120] },
  "antenna.light": { "sheet": "antenna", "grid": [170, 120], "start": 0, "count": 5 },
  "both": ["nib", "cell"]
}
```

- **What an image name can be:**
  - a file;
  - a cell of a sheet (`rect` in the sheet's pixels);
  - a run of cells (`grid` cell size, `start`, `count`, counted left to right, top to bottom);
  - a list of other names.

  Runs and lists are **frame lists**.
- **Bare file names:** an element may name a file directly (`"image": "rail/x.png"`).
- **Size and resolution:** the image fills the element's box whatever its pixel size. Paint at
  6–10 px/mm. Each image is drawn once per size and cached.

## Elements

```json
"elements": {
  "vial": {
    "size": [17, 9], "anchor": [16, 4.5],
    "image": "vial",
    "ink": { "mask": "vial.ink", "from": [8, 8.1], "to": [8, 0.9], "source": "volume" },
    "triggers": { "click": "deal:levels", "scrollUp": "volume:+5", "scrollDown": "volume:-5", "middleClick": "mute" },
    "tag": "Sound {{volume|percent}}"
  }
}
```

| Key | Meaning |
|---|---|
| `size` | `[w, h]` of the element's box. Required. |
| `anchor` | The point that layouts place (the rail's working end, a slot's centre, the screen corner). Default `[0, 0]`. |
| `image` | The default look. |
| `frames` | `{source, images, min = 0, max = 1}`: the frame of a frame list chosen by a value. |
| `states` | `[{when, image \| frames, ink, overlay, markers}]`: the first whose `when` holds replaces those keys. |
| `ink` | Iron-gall ink (or `colour` from `inks`) poured into `mask` from `from` toward `to` by `source` (0–1); `bands: {when}` adds canary bands. |
| `overlay` | Drawn over the ink. |
| `markers` | `[{at, shape: "dot" \| "ring", radius, colour, when}]`: drawn status marks (shape carries meaning, not only colour). |
| `regions` | Sub-buttons (below). |
| `hit` | The element's own active area (below). Default: its drawn pixels. |
| `triggers` | `click`, `rightClick`, `middleClick`, `doubleClick`, `scrollUp`, `scrollDown` → actions. |
| `tag` | Hover text; a template (below). Default: the click action's label. |
| `animations` | Below. |
| `visibleWhen` | A condition; hidden when false. |
| `dither`, `shadow` | The shell's finish, default on. |

**Conditions** (`when`, `visibleWhen`, `bands.when`, marker `when`):
- `{source, eq | ne | lt | lte | gt | gte | in: [...] | truthy: true}`
- `{all: [...]}`, `{any: [...]}`, `{not: {...}}`

**Templates:** `"Sound {{volume|percent}}"`. Filters are `percent`, `int`, `upper`, `lower`
and `plural:word`.

### Regions

```json
"regions": [
  { "id": "writing", "frames": { "source": "notifications.unread", "min": 0, "max": 6, "images": "writing" } },
  { "id": "clip", "rect": [1.4, 7.2, 12, 12], "image": "paperclip", "triggers": { "click": "clipboard" }, "pad": 4 }
]
```

- **What a region is:** a look of its own (`image`, `frames`, `states`) drawn into `rect` (the
  whole box if omitted), with its own `triggers`, `tag`, `hit`, `pad`, `animations` and
  `visibleWhen`.
- **Order:** the last listed is on top, both when drawing and when clicking.
- **Decoration:** a region without triggers draws but takes no clicks.
- **Unavailable actions:** a region whose actions can't do anything (clipboard history off,
  tray off, a missing command) is neither drawn nor clickable.

### Active areas

`hit` is one shape or a list; a point inside any of them counts:

| Shape | |
|---|---|
| `{"rect": [x, y, w, h]}` | |
| `{"circle": [cx, cy, r]}` | |
| `{"polygon": [[x, y], ...]}` | |
| `{"alpha": true}` | The drawn pixels (default). For a region: its own pixels grown by `pad` px (default 4). |
| `{"mask": "imageName"}` | Opaque pixels of a mask image over the box (or the region's rect). |

### Animations

```json
"animations": {
  "hoverIn":  { "tween": { "x": 1.5 }, "duration": 140 },
  "hoverOut": { "tween": {}, "duration": 180 },
  "press":    { "tween": { "x": -1, "scale": 0.98 }, "duration": 60, "easing": "outCubic" },
  "change:network.connecting": { "frames": "antenna.pulse", "fps": 12, "mode": "loop" }
}
```

- **Events:** `hoverIn`, `hoverOut`, `press`, `release`, `click`, `load`, and `change:<value>`
  (whenever that value changes). A region has its own events.
- **Frames:** `{frames, fps = 12, mode}` shows a frame list over the look.
  - `once` returns to the look; `hold` stays on the last frame; `loop` and `pingpong` repeat.
  - Each frame is composed once and cached, so replaying is cheap.
  - A loop keeps the element repainting: use it only while something is in progress.
- **Tweens:** `{tween: {x, y, rotate, scale, opacity}, duration = 150, easing}` move the element
  from wherever it is to that pose; `{}` is rest. They are transforms, not repaints.
  - Easings: `linear`, `inOutQuad`, `outCubic`, `outBack`.
  - On the element only (not regions).
- **Transitions option:** when the Transitions reading option isn't "full", tweens jump to their
  end, `hold` frames jump to the last, and others are skipped.

## Values

What conditions, frames, ink and templates can read:

- **Audio:** `volume` (0 when muted), `volume.raw`, `muted`, `audio.available`, `mic.muted`
- **Brightness:** `brightness`, `brightness.available`
- **Battery:** `battery.present`, `battery.level`, `battery.state` (`absent`, `dis`, `chg`,
  `held`, `full`)
- **Network:** `network.connected`, `network.wired`, `network.stage` (0–4),
  `network.connecting`, `network.failed`, `network.name`
- **Bluetooth:** `bluetooth.available`, `bluetooth.on`, `bluetooth.connected` (count),
  `bluetooth.connecting`
- **Notifications:** `notifications.unread`, `notifications.dnd`
- **Clipboard:** `clipboard.count`
- **Media:** `media.present`, `media.playing`, `media.title`
- **Time:** `time.hour`, `time.minute`
- **Mode:** `mode` (`light` | `dark`)

## Actions

Triggers name actions; nothing else can run:

| Action | Does |
|---|---|
| `launcher` | Toggle the launcher |
| `deal:<hand>` | Deal a hand (config group or skin hand) |
| `notifications`, `clipboard`, `tray` | Deal those sheets |
| `sheet:<name>` | Open a sheet |
| `mute`, `microphone` | Toggle |
| `volume:+5`, `brightness:-10` | Change by percent |
| `workspace:<n \| name \| next \| previous>` | Switch workspace |
| `minimize`, `lock`, `dnd`, `hide` | |
| `media:play \| next \| previous` | |
| `command:<name>` | A named command from `[commands.custom]` in config.toml |
| `none` | |

**Commands:** a skin can name a command but never supply one. Define the argv in config.toml:

```toml
[commands.custom]
screenshot = ["grim", "-g", "0,0 1920x1080", "/tmp/shot.png"]
```

## Layouts

**Rail.** The order of the strip, top to bottom:

```json
"rail": { "items": [
  { "element": "tray", "place": "center" }, { "element": "nib" }, { "system": "rule" }, { "system": "workspaces" },
  { "element": "vial", "hand": "levels" }, { "system": "hands" }, { "system": "spacer" },
  { "system": "media" }, { "system": "clock" }, { "foot": "paper" } ] }
```

- **Element items:**
  - `place: "end"` (default) puts the element's anchor at the rail's working end, on the slot's
    centre line; `"center"` puts it on the strip's centre.
  - `gap` sets the space around the element (px, default 2).
  - An item with `hand` shows only while that hand is on the rail (`rail.hands` in config) and
    present (a battery for `battery`).
- **System parts:**
  - `rule` and `spacer`;
  - `workspaces`;
  - `hands`: configured hands that have no element, shown as illuminated initials;
  - `media`: where removable media open;
  - `clock`.
- **Foot:** one element anchored at the screen's bottom-left corner.

**Dock.** `"dock": {"before": [...], "after": [...]}` lists element ids placed either side of
the window entries, centred on their anchors in the dock's height. Elements in the dock deal
from the top.

## Cards and hands

```json
"cards": { "inkwell": { "title": "Ink", "face": "inkwell-face", "back": "inkwell-back", "value": "{{volume|percent}}",
                        "orientation": "portrait", "chin": [0, 174, 154, 41], "ink": "#211C15" } },
"hands": { "desk": { "label": "Desk", "cards": ["skin:inkwell", "volume"] } }
```

- **Naming:** skin cards are called `skin:<id>` wherever a hand lists them. That works in skin
  hands and in config groups too (`config.toml` accepts `skin:` names).
- **Faces and backs:** both are elements, scaled to the card's width. Clicks on the face run its
  triggers (regions included). A `back` adds the dog-ear and right-click flip.
- **Chin:** `chin` is the rect (element units) for the live title and value text. Set it to
  `false` for no chin text.
- **Hands:** skin hands are dealt by `deal:<name>`. A config group of the same name wins.

## Removable media

```json
"devices": { "usb": { "image": "devices/usb.png", "envelope": "devices/usb-envelope.png" },
             "tome": { "image": "devices/tome.png", "size": [120, 80], "like": "ereader", "name": "Tome" } },
"media": { "seal": "devices/seal.png", "sealCracked": "devices/seal-cracked.png" }
```

- **Built-in kinds:** keep their geometry; your image fills their local rect: length × width
  with the leading end (the end facing into the screen) on the right, as in the default
  images.
- **New kinds:** map one with `[media.overrides]` in config. It needs `size: [length, width]` in
  mm, and `like` (the built-in pose to copy).
- **Locked volumes:** `envelope` is drawn over a LUKS volume, and the seal on top.

## Card art and pins

```json
"cardArt": { "volume": { "front": "cards/sound.png", "dark": "cards/sound-dark.png", "focus": [0.5, 0.4] } },
"pins": { "firefox": "pins/firefox.png" }
```

- **Card art:** cropped to fill the card's art panel around `focus`, with the cards' dither
  grain and level-driven luminance and saturation.
- **Pins:** fill the launcher's plates. Keys are desktop ids from `launcher.pins`.

## Materials

```json
"materials": {
  "vellum": { "image": "materials/vellum.png", "size": [1024, 1024] },
  "fray":   { "image": "materials/fray.png", "size": [64, 64] },
  "sheen":  { "image": "materials/sheen.png", "size": [256, 1], "span": 1.2 },
  "glint":  { "image": "materials/glint.png", "size": [64, 64] },
  "patina": { "image": "materials/patina.png", "size": [512, 512] },
  "ramps":  { "image": "materials/ramps.png", "size": [4, 7], "rows": ["gold", "silver", "pink", "green", "copper", "patina", "brass"], "lengths": [4, 4, 4, 4, 4, 3, 4] }
}
```

`size` must match the image.

| Field | Channel encoding | Notes |
|---|---|---|
| `vellum` | R: texture, 128 = flat | One texel per logical px, tiled. |
| `fray` | R: edge threshold | Per logical-px grain cell; lower frays more. |
| `sheen` | R: foil band strength ÷ 2; G: where glints may appear | Along the card diagonal, `span` long. |
| `glint` | R: glint noise | |
| `patina` | R: how far verdigris spreads; G: its tone | In logical px. |
| `ramps` | One row per material; its tones, dark to light, from the left | |

**What stays code:** colours of the paper, ink and semantic states, which are config palette
tokens. The dither matrix, card geometry, level and mark logic, bands, and the focus halo's
shape are code too.

## Selection: loupes, ring, initial

`loupes` in skin.json, one entry per surface (`rail`, `dock`):

```json
"loupes": {"rail": {"size": [54, 57], "light": "materials/loupe-rail-light.png",
  "dark": "materials/loupe-rail-dark.png", "glass": "materials/loupe-rail-glass.png",
  "ring": {"light": "materials/ring-rail-light.png", "dark": "materials/ring-rail-dark.png"}}}
```

- `size` is logical px (diameter, diameter + the contact shadow). Draw at 4× for crisp HiDPI.
- `light` / `dark`: the loupe (brass, glass shading, shadow) per mode, drawn over the content.
- `glass`: the mask. Alpha decides where the magnified content shows (white, opaque = glass);
  anything outside is clipped. It need not be a circle.
- `ring`: the fallback selection indicator, used instead of the loupe with Accessibility's
  reduced effects (no magnification, no glass, solid inner ring for contrast).
- `initial`: the gold ground behind a hand's letter when the hand has no element of its own.

## Not yet images

- **Focus halo** (`Halo.js`) and the card band pattern: still painted; colours come from the ramps.
- **Workspace numerals, clock, initial letters:** live text, not art.

## Verify on hardware (3)

- `?v=` cache-busting on `file://` image URLs under Qt.
- 9-argument `drawImage` (sheet cells) in QML's Context2D.
- `Canvas.unloadImage` after rasterising.
- The first frame painting the procedural stand-ins before the material images install.
- `onImageLoaded` repaints.
- Material decoding in blocks on the rail's canvas.
