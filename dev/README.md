# Reproducible Arch runtime

The pinned Dockerfile uses Arch archive **2026/10/30**, Quickshell **0.3.2**, Qt
**6.12**, Sway **1.12**, wlroots **0.20** and Mesa **26**. `/opt/packages.txt`
records the normal image's installed packages. Keep the entire Qt stack together.
Tests run as UID 1000 with networking disabled, no physical display/input/GPU,
no host session sockets/system bus and no privileged container.

## Fresh build

```sh
bash dev/build.sh
mkdir -p dev/cache
curl -fL https://github.com/mangowm/mango/archive/refs/tags/0.18.4.tar.gz -o dev/cache/mango-0.18.4.tar.gz
bash dev/run.sh bash dev/build-mango.sh
bash dev/run.sh bash dev/build-pointer.sh
bash dev/run.sh bash dev/test-all.sh
```

BuildKit is required. The CA comes from CODEX_PROXY_CERT when set, otherwise the
host CA bundle. It is a build secret for package transfer, not baked into the
image. TLS and pacman signature checks remain enabled. Normal Docker proxy
configuration is used. Runtime networking stays disabled; fetch source before
entering the test container. Mango's build script checks the pinned source hash:
`e4ec09a020b8227dc7044cf9e16f4563d28a24d99a08a51aed05cc8b95cbbbfa`.
It builds unmodified Mango/mmsg 0.18.4 with Xwayland disabled and copies developer
binaries into ignored `dev/`. The build directory is disposable. Do not install those
binaries over a working compositor. Pointer helper sources/protocol are included.

`test-all.sh` runs syntax/unit/strict-lint validation, then nine fresh private
D-Bus + headless Sway sessions: foundation, artifacts, isolated feature smoke,
audio, live reload/configuration, Mango adapter protocol, greeter protocol, v3
configuration (`single-config`) and the Session deck (`session-ui`).
Runtime failures stop the runner, record a nonzero suite exit and leave subsequent
suites marked NOT RUN. Strict lint remains separately recorded as exit 1; a
runtime pass does not call lint clean. Results/logs/screenshots are under
`artifacts/development` and `artifacts/portable`; the two v3 suites also write
logs and screenshots to `artifacts/v3`. `session-ui` waits past the 15-second
command limit on purpose, so it takes about 30 seconds.

For an individual section:

```sh
bash dev/run.sh dbus-run-session -- bash dev/headless.sh python tests/runtime/artifacts.py
bash dev/run.sh dbus-run-session -- bash dev/headless.sh bash dev/audio-session.sh python tests/runtime/audio.py
bash dev/run.sh dbus-run-session -- bash dev/headless.sh python tests/runtime/compositor.py
bash dev/run.sh dbus-run-session -- bash dev/headless.sh python tests/runtime/greeter-protocol.py
```

Sway uses WLR_BACKENDS=headless and the Pixman renderer. Qt Quick uses software
rendering. The runner copies Sway into private tmp to avoid packaged capabilities
inside the container. It provides a private writable home/runtime/tmp/shared
memory. Application-launch tests install one harmless desktop entry in that
home. Virtual keyboard and pointer devices exercise actual Wayland input. Private PipeWire/
WirePlumber plus virtual sinks/source are real services; no physical audio is
claimed. NetworkManager/BlueZ/UPower/logind/polkit/backlight are absent.
MPRIS/tray peers, Mango server and greetd authentication are explicit fixtures;
their real transports/native clients run, but they are not real user applications,
a Mango compositor or PAM. Session actions are harmless marker substitutes.

## Prepared cloud rootfs / Docker VFS fallback

This workspace has `/workspace/arch-runtime` ready for:

```sh
bash dev/run-vfs.sh bash dev/test-all.sh
```

The runtime was extended by SHA256-verified extraction of matching Arch packages
in `test-packages.json` and `mango-build-packages.json`; these additions are not
registered in its original pacman DB. Fresh Docker builds install them normally.

The fallback binds that userspace read-only, private writable tmpfs locations,
and the project read/write. A tiny helper uses host /usr,/lib,/lib64 read-only
for chroot, then drops to UID 1000. It binds read-only /proc and uses the matching
host PID namespace so PipeWire's peer-credential/proc checks work. Process
visibility is consequently broader than a normal container; use the normal
runner when available. There are no host session sockets, Docker socket,
physical input/GPU or system bus inside the tested desktop.

For another VFS machine, allow at least 12 GB free for build/export/run. Prefer
its owner's normal copy-on-write Docker storage. Do not change a running daemon's
storage driver or remove internal Docker directories. With sufficient space:

```sh
bash dev/export-rootfs.sh /tmp/illuminated-rootfs.tar.gz
mkdir -p /workspace/arch-runtime
# Use a new empty task-owned destination:
tar --no-same-owner -xzf /tmp/illuminated-rootfs.tar.gz -C /workspace/arch-runtime
export ILLUMINATED_ROOTFS=/workspace/arch-runtime
bash dev/prepare-rootfs.sh
bash dev/run-vfs.sh bash dev/test-all.sh
```

## Genuine compositor probes

Mango 0.18.4 built successfully. Its real config parser (`mango -c FILE -p`)
accepted both integration and generated theme configuration. Its real headless
renderer failed immediately without a DRM FD; Scenefx requires GLES2 in this
build. The log is `artifacts/portable/mango-headless.txt`. The adapter test instead
uses the genuine built mmsg against an explicitly identified Unix-socket fixture.
It covers initial snapshots, multiple active tags/client memberships, dispatch,
missed-event reconciliation, disconnect invalidation and reconnect.

The previous foundation attempted Hyprland both nested and without a parent
Wayland display, but failed on backend/allocator requirements. This stage did
not repeat that failed backend pursuit or patch either compositor. The retained
`probe-hyprland.sh` records probes; its exit zero only means diagnostics were
recorded. Sway runtime success establishes no actual Hyprland/Mango compatibility.
Hardware/compositor/session acceptance is in the sequential testing guide.
