# Continuation prompt: finish the Illuminated Desktop simplification

You are continuing an interrupted implementation. Finish the remaining work in
[SIMPLIFICATION-HANDOFF.md](SIMPLIFICATION-HANDOFF.md), using this checkpoint to
avoid redoing completed tasks. Read that document and [docs/STATUS.md](docs/STATUS.md)
before editing. Preserve the visual/interaction contract; this is not a redesign.

The user requested environment setup, then the entire simplification handoff.
Try genuine headless Hyprland or Mango if the environment supports them; otherwise
use headless Sway. Both were tried here and failed on renderer/backend prerequisites,
so Sway is the established runtime. Do not confuse the Mango IPC fixture with a
working Mango compositor.

## Checkout and committed progress

- Repository: `/workspace/illuminated-desktop`.
- Working branch: `simplify/phase-3`.
- Last implementation commit: `1da8155`; this documentation commit follows it.
- Use the existing checkout. Do not create a worktree unless the user requests one.
- Keep one branch per phase and one conventional commit per task. Existing phase
  branches are ancestors of the current branch; do not reset to `main`.

Completed implementation commits, in order:

| Commit | Completed work |
| --- | --- |
| `972c4db` | Phase 1 verification fixes: notification filter referenced deleted `now`; skin helper `layer()` collided with Qt Quick's property |
| `fc5be86` | Phase 1.7: left-origin hands only; remove duplicate packaged `light`/`session` groups; tests/docs/defaults updated |
| `01914ed` | Phase 2.1: stable dock delegates, native QObject identity for Hyprland and keyed live lookups for Mango |
| `edbf120` | Phase 2.2: stable workspace delegates and removal of unused adapter-facing title |
| `e4e3342` | Phase 2.4: remove unconditional Hyprland reconciliation timer; retain reconnect/startup machinery |
| `2a9ebc5` | Phase 2.3: FileView brightness reads from sysfs; brightnessctl writes; controlled fixture tests |
| `4f9c843` | Phase 3.1: per-kind card adapters; battery-only details/FileView component |
| `1da8155` | Phase 3.2: built-in behavior metadata moved out of configuration; labels/sheets/confirmation remain configurable |

Do not repeat these removals. `cards.*.orientation`, `.interaction` and
`.alternatives` are intentionally gone from config/schema/generated defaults.
`quickshell/cards/kinds/Metadata.js` supplies their previous behavior. A comparison
against all 16 old definitions passed. Custom skin orientation remains supported.

## Unfinished Phase 3.3: preserve and finish this first

At checkpoint, the following implementation changes are **uncommitted**:

- `dev/README.md`, `dev/test-all.sh`;
- `quickshell/artifacts/{ArtifactCard,CardAction,ServiceCard,SplitText}.qml`;
- `quickshell/media/DeviceCard.qml`;
- new `tests/runtime/text-face.py` and `text-face.qml`.

They consolidate text parameters into shared face objects, use `mapToItem` for
origins, retain two clipped text copies, and add a real-QML geometry regression
suite to the runner. The face objects include the coordinate item. Separate plain
and washed variants preserve places where text deliberately ignored the wash.
Mapping reacts to face/geometry/text and immediate-parent geometry changes; review
whether additional ancestor-layout changes need coverage. No idle polling was added.

A portable snapshot is committed as
[docs/handoff/phase-3.3-wip.patch](docs/handoff/phase-3.3-wip.patch).
It includes both new tests. This is unfinished work, not a validated implementation
commit. The handoff commit itself does not stage the actual implementation files.

On this existing machine the changes are already present: do not apply the patch
twice or overwrite newer edits. To recognize that state without modifying files:

```sh
git status --short
git apply --reverse --check docs/handoff/phase-3.3-wip.patch
```

On a clean checkout of this handoff commit, recover them with:

```sh
git apply --check docs/handoff/phase-3.3-wip.patch
git apply docs/handoff/phase-3.3-wip.patch
```

If either check fails, inspect the differences rather than resetting or forcing it.

Phase 3.3 observed outcomes:

- Non-strict repository validation passed; native QML metadata warnings remain.
- New text-face test passed nested translation, resize and vertical wash clipping.
- Full artifacts and audio suites passed with these changes.
- Untraced Session UI timed out on its first `group power` IPC call (10-second
  existing deadline), before the interaction assertions. This is unresolved.
- A subsequent diagnostic run under strace completed **both** Session UI PASS
  sections, with exit `0`. This result was recovered after reconnect. It does not
  erase the untraced failure or establish its root cause.
- Inspect/reproduce the untraced startup timeout; rerun without tracing, preserve
  the real result, inspect relevant captures, update STATUS, and commit Phase 3.3
  only when the result and remaining limitations are accurately understood.

Local evidence, if retained (these artifacts are ignored and are not in Git):
`artifacts/development/phase33-{validation,text-face,artifacts,audio,session-ui}*`,
`phase33-session-trace.{txt,exit}`, and
`artifacts/v3/session-startup.strace`. The trace captured polling/synchronization
syscalls, not D-Bus payloads. Ignored diagnostic helpers are in `dev/cache/`.

## Environment and how to validate

The actual prepared image is `illuminated-dev`: pinned Arch archive 2026/10/30,
Quickshell 0.3.2 and Qt 6.12. `dev/mango`, `dev/mmsg` and
`tests/runtime/native/pointer` were built. Check that they survived restoration.
Read the cloud runtime skill and current environment status on resume. A reported
starting/offline instance must become available before inspecting its filesystem.
The environment suffered intermittent capability-query/reconnect failures, but
was connected and its checkout intact when this handoff was written.

Normal route, from the repository root:

```sh
bash dev/run.sh bash scripts/validate.sh
bash dev/run.sh bash dev/test-all.sh
bash dev/run.sh dbus-run-session -- bash dev/headless.sh python tests/runtime/text-face.py
bash dev/run.sh dbus-run-session -- bash dev/headless.sh python tests/runtime/session-ui.py
```

For audio use `dbus-run-session -- bash dev/headless.sh bash dev/audio-session.sh
python tests/runtime/audio.py` inside the runtime. Read `dev/README.md` for details.
Do not assume the README's historical `/workspace/arch-runtime` exists; the normal
Docker image works here. Do not change the daemon's VFS storage driver.

A task-owned container named `illuminated-workbench` was left running for continued
work; it uses the same image, `/project` bind mount, network disabled, and 256 MB
shared memory. It avoids slow VFS copies. Inspect before reusing it. Its filesystem
home persists, unlike a new container. **The artifacts persistence test leaves DND
enabled**: reused homes caused a false notification-popup failure. Use a fresh
throwaway home for each independent acceptance run, for example:

```sh
docker exec illuminated-workbench bash -c '
  test_home=$(mktemp -d)
  trap '\''rm -rf "$test_home"'\'' EXIT
  env HOME="$test_home" dbus-run-session -- bash dev/headless.sh \
    python tests/runtime/session-ui.py > artifacts/development/session-resume.txt 2>&1
  result=$?
  echo "$result" > artifacts/development/session-resume.exit
  exit "$result"
'
```

Persist exit files inside the container/project: reconnects lost command session
handles, and a missing result does not mean success. Stop the task-owned workbench
when the implementation is finished; do not stop unrelated containers.

If rebuilding: read the Docker runtime guidance and `dev/build.sh`. Archive access
requires `archive.archlinux.org` (already added to the saved environment settings).
Observed HTTP 502 downloads required a **setup-only** Dockerfile copy adding
`--retry 5 --retry-delay 2` to curl. That copy is at
`/workspace/illuminated-setup/Dockerfile` if retained. Recreate it from
`dev/Dockerfile` if needed; do not weaken TLS, signatures or checksums. The complete
install/start instructions were also saved in the environment configuration draft.
No GitHub token was needed; existing HTTPS proxy authentication worked.
Publication was never confirmed. A saved draft or working current machine is not
proof of a published/fresh-task environment.

## Baseline failures and evidence discipline

Last committed Phase 3.2 validation: **155 JavaScript tests and 78 Python tests
passed**; non-strict QML validation exit `0`. Strict lint remains a failing native
metadata-warning baseline; do not describe it as clean.

A full frozen Phase 2 recheck passed artifacts, smoke, audio, compositor, greeter
and Session UI. It retained these earlier failures:

- foundation: `launcher not reopened` (known intermittent failure);
- reload: notification D-Bus request exceeded 8 seconds;
- single-config: configuration IPC request exceeded 15 seconds.

Snapshot evidence is under `/workspace/illuminated-setup/phase2/artifacts/` if it
survived. A separate temporary startup probe measured status IPC at 0.30 s and a
successful notification D-Bus request at 21.83 s. Observed Canvas paints were at
most 529 ms, with one 761-ms material decode. **This does not prove that Canvas
causes the long startup requests.** Investigate rather than silently extending
assertion deadlines or claiming all suites pass.

The repository runner stops after the first runtime failure. For baseline
collection, continuation helpers attempted all suites; their individual exit
files, not a concluding aggregate message, establish outcomes. Do not count stale
captures or zero-test runs as validation. The WIP runner adds `text-face`, making
ten suites; Phase 6 may add more.

## Remaining implementation, in order

1. **Finish Phase 3.3** as above, then commit its implementation/tests/docs separately.
2. **Phase 3.4:** inline the one-prefix CardKinds helper into CardsLayer, preserve
   family routing coverage, and remove the obsolete helper. All three production
   card types currently disable decoration and set zero insets. Verify that, then
   remove ArtifactCard's decoration/inset/Paper indirection and corresponding
   redundant assignments. Keep Paper where the greeter still uses it.
3. **Phase 4:** reduce single-use Settings/Theme aliases; use Settings.option for
   raw config and retain useful derived/shared properties. Preserve test overrides
   and greeter behavior. Generate Reading.js option enums from TOML schema during
   `illuminated defaults --write-json`. Move directory bootstrap processes into
   apply/install only if first launch without apply still works; otherwise retain
   them and document why.
4. **Phase 5, steps 1–5:** first measure startup/first rail frame, first launcher,
   first hand, 2-second volume drag and idle Canvas count. Run foundation with
   wallpaper disabled and then rail disabled; distinguish measurements from causes.
   Perform the two Vellum spikes in both palettes, capture a contact sheet, and
   decide D2 from visual evidence. Convert FocusHalo to baked nine-slice BorderImage,
   then Vellum, then card bases/live clipped fills, sheen, patina, numeral glow and
   card art to native items/baked images. No per-pixel runtime drag work.
5. **Phase 6 is mandatory:** implement trusted QML skins and per-file overlay,
   data-only skin.json, Rail/DockChrome/Cards components, SkinItem input/accessibility
   and shape containment, typed ShellState, Actions, baked InkFill sheets and Marker.
   Bake default finishes/shadows at 1×/@2x and port all default elements and the
   example skin without losing their interactions. Move mutable JS registries to
   reactive SkinStore state and remove the config-to-skin import inversion. Warn
   and fall back for old-format skins in apply/doctor/shell. Replace the DSL and
   doctor validator with the specified native QML flow and runtime tests. Rewrite
   SKINS.md and include the old-to-new element mapping in the commit description.
6. **Return to Phase 5, steps 7–9:** remove runtime decode/procedural fallback paths
   only when no consumer remains; retain bake painters and their useful harness.
   Replace the handwritten QML tokenizer only after deliberate unknown-type and
   missing-import probes establish qmllint coverage. Keep real Quickshell pitfall
   checks. Repeat measurements and record actual deltas and idle Canvas counts.
7. **Phase 7:** lock directly in-process for the shell-lock Sleep path, suspend only
   after secure, preserve timeout/fallback semantics and external CLI callers, and
   test with harmless suspend markers under Sway. Write the requested hypridle vs
   logind delay-inhibitor design note; do not implement an untestable logind client.
8. **Finish:** run required checks, review diffs/references, update STATUS/CHANGELOG,
   commits/line deltas and reusable start instructions. Produce concrete Inspiron
   acceptance steps for every remaining L item. Report all residual failures and
   limitations honestly. Do not claim publication or genuine compositor validation
   without new evidence.

Use the original handoff for each task's full acceptance criteria; this list does
not waive them. Phase 5 ordering is specifically **5.1–5.5 → 6 → 5.7–5.9**.

## Decisions and constraints that remain binding

- D1: QML skins was explicitly decided by the user; Phase 6 is required.
- D2: perform the visual spike; prefer palette-independent overlays if acceptable,
  otherwise bake through apply with Node and document the resulting dependency.
  This choice has **not** been settled by the limited startup probe.
- D3: keep the shell lock; simplify its driving path.
- No new runtime dependencies except the handoff's explicitly allowed D2 choice.
- No new ShaderEffect/MultiEffect uses: software rendering must remain supported.
  Existing Loupe MultiEffect rendering remains a local acceptance item.
- Do not run the installer against a real home. Use throwaway test homes and
  harmless session-action substitutes.
- Do not change the greeter, integration files, Mango protocol logic,
  RemovableMedia event-then-snapshot design, or protected pure logic behavior
  (Geometry, CardModel, MediaLogic, WindowLogic, MangoLogic). The explicitly
  requested obsolete Geometry deck removal was already completed.
- Label changes **V** (runtime verified), **U** (unit/static only), **L** (local
  acceptance). Mango and greeter protocol fixtures must be labelled as fixtures.
  Sway establishes no actual Hyprland/Mango, hardware, real PAM or GPU validation.
- Hyprland previously failed both nested and without a parent: missing Wayland
  protocols/no allocator. Mango 0.18.4 built but its GLES renderer needed a DRM FD.
  Use Sway unless the available hardware/backend capability actually changes.
