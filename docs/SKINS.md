# Skins

A skin is a folder of QML files and images. The default skin is
`quickshell/skins/default/`; yours is `~/.config/illuminated/skin/` (or `skin.path` in
`config.toml`). A skin is trusted code, like the rest of the rice: it runs in the shell.

## Layout

```
skin/
  skin.json        # data only: name, about, devices, media, materials, loupes, cardArt, pins, initial
  Rail.qml         # the rail, top to bottom (a RailLayout)
  DockChrome.qml   # objects before and after the dock's windows (a DockLayout)
  Cards.qml        # optional: cards and hands the skin adds (SkinCards)
  Vial.qml …       # the objects Rail.qml and DockChrome.qml use
  elements/*.png   # their art; a "-2x" file beside each for large or HiDPI output
```

## Overlay rule

**By file.** `illuminated apply` builds `~/.config/illuminated/generated/skin/`: every file of
the default skin, with each file of yours in its place (and any you add). So a skin with only
`Vial.qml` changes only the vial; one with `Rail.qml` rearranges the rail and still uses the
default objects it names. After editing your skin, run `illuminated apply`: the shell reloads
(Quickshell does not watch QML outside its own folder). Until `apply` has run, the shell uses
the default skin.

`skin.json` is data and merges **key by key** over the default's (`null` removes a key).

A `skin.json` with `elements`, `rail.items` or `dock.before`/`dock.after` is the pre-QML format:
`apply`, `doctor` and the shell say so, and the default skin is used instead.
`illuminated doctor` runs `qmllint` over your QML when it is installed.

## Rail.qml

```qml
import QtQuick
import qs.skin
RailLayout {
    Tray {}  Nib {}  RailRule {}  RailWorkspaces {}  RailRule {}
    Vial {}  Antenna {}  Converter {}  Matchbox {}
    RailHands {}          // hands in rail.hands that no object deals: illuminated initials
    RailSpacer {}  MediaBay {}  RailRule {}  RailClock {}
    foot: PaperCorner {}  // anchored at the screen's bottom-left corner
}
```

`DockChrome.qml` is a `DockLayout { before: [ … ]; after: [ … ] }`.

## SkinItem

The base of every object. Its box is `size` in `units` (`"mm"`: life size on this output;
`"px"`: logical px); `anchor` (same units) sits at the rail's working end, or the strip's centre
with `place: "center"`. Baked art may reach `shadowMargin` px beyond the box.

| Member | |
| --- | --- |
| `hand` | the hand it deals; it shows only while that hand is in `rail.hands` |
| `shown` | its own condition (for example `ShellState.batteryPresent`) |
| `tag` | hover text, and the accessible name (Tab, Enter and Space work) |
| `hitShape` | `HitRect { rect }`, `HitCircle { center; radius }`, `HitPolygon { points; pad }`, in units; default: the box |
| `hovered`, `pressed` | pointer state, for `Behavior`s and states |
| `clicked(button)`, `wheelStep(direction)`, `doubleClicked()` | signals |
| `run(action)` | runs an action with this object's screen and height |
| `mm(x)`, `px(x)`, `unit`, `pxmm` | sizes |

Animation, states and timing are plain QML (`Behavior`, `State`, `NumberAnimation`); see
`skins/example/Seal.qml` and `Nib.qml`.

## Art

`FrameImage { file: Qt.resolvedUrl("elements/x.png"); count; frame }` shows one frame of a sheet
(frames in one row). It picks `x-2x.png` when the art is drawn more than 1.25× larger in device
px. Not `@2x`: Qt would read that name as a 2-DPR image and halve its size.

`InkFill { file; level; steps: 24; variants; variant }` is a FrameImage whose frame follows an ink
level; a sheet may hold several runs of `steps + 1` frames (the converter: discharging, charging
with canary bands, held). `Marker { at; radius_; ring }` draws a canary dot or ring.

The default skin's sheets are baked: `node scripts/skin/bake-elements.cjs` composes each look of
each object from `scripts/skin/elements.json` with the shell's finish (dither, drop shadow), at 1×
and 2× of the 24″ 1080p scale (1920/531 px per mm). Elsewhere the art is scaled.

## ShellState

Typed properties, each with its own change signal:
`volume` (0–1, 0 when muted), `volumeRaw`, `muted`, `audioAvailable`, `micMuted`, `brightness`,
`brightnessAvailable`, `batteryPresent`, `batteryLevel`, `batteryState` (`absent` `chg` `full`
`held` `dis`), `networkConnected`, `networkWired`, `networkStage` (0–4), `networkConnecting`,
`networkFailed`, `networkName`, `bluetoothAvailable`, `bluetoothOn`, `bluetoothConnected`,
`bluetoothConnecting`, `unread`, `dnd`, `clipboardCount`, `clipboardEnabled`, `mediaPresent`,
`mediaPlaying`, `mediaTitle`, `mode`.

## Actions

`run("name")` or `run("name:arg")`: `launcher`, `deal:<group>`, `sheet:<sheet>`,
`notifications`, `history`, `clipboard`, `tray`, `mute`, `volume:±n`, `brightness:±n`,
`microphone`, `workspace:next|prev|<n>`, `minimize`, `lock`, `media`, `dnd`, `hide`,
`command:<name>` (a command from `[commands.custom]`). `Actions.available(a)` and
`Actions.label(a)` say whether it can run now and what it is called. `command:` is a
convenience for your own commands, not a security boundary: a skin is code.

## Cards.qml

```qml
SkinCards {
    SkinCardSpec { name: "inkwell"; title: "Ink"; value: Math.round(ShellState.volume * 100) + "%"
                   face: Component { InkwellFace {} } }      // back: Component { … } makes it flippable
    SkinHand { name: "desk"; label: "Desk"; cards: ["skin:inkwell", "volume"] }
}
```

A face fills the card and gets `card`; a click reaches the face's `SkinItem` under the pointer.

## skin.json

`devices` (removable-media art and, for kinds you add, `size` and `like`), `media` (`seal`,
`sealCracked`), `materials` (vellum, fray, sheen, glint, patina, ramps images), `loupes`,
`initial`, `cardArt` (`{front, dark?, focus?}` per card kind), `pins` (launcher pin art).
Paths are relative to the skin folder.
