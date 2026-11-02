# Documentation consulted

Checked on 2026-10-31. These are primary sources, not copied third-party dotfiles.

| Source | Decision informed |
| --- | --- |
| [Arch Extra: quickshell](https://archlinux.org/packages/extra/x86_64/quickshell/) | Official packaged runtime; listed as 0.3.2-1 when checked |
| [Quickshell changelog](https://quickshell.org/changelog/) | Lua integration in 0.3.0; new Hyprland workspace address support in 0.3.2 |
| [Quickshell 0.3.2 guide](https://quickshell.org/docs/v0.3.2/guide/) | Current versioned documentation entry point |
| [Guided introduction](https://quickshell.org/docs/v0.3.1/guide/introduction/) | Explicit paths, `Variants`, relative imports, singleton lifecycle, native clock |
| [Hyprland singleton](https://quickshell.org/docs/v0.3.2/types/Quickshell.Hyprland/Hyprland/) | Output/workspace object models, focused title, Lua mode |
| [HyprlandWorkspace](https://quickshell.org/docs/v0.3.2/types/Quickshell.Hyprland/HyprlandWorkspace/) | Active/focused distinction, urgency, toplevel model, native activation |
| [HyprlandMonitor](https://quickshell.org/docs/v0.3.1/types/Quickshell.Hyprland/HyprlandMonitor/) | Output identity and active workspace |
| [PanelWindow](https://quickshell.org/docs/v0.3.1/types/Quickshell/PanelWindow/) | Three anchors, reserved exclusive zone, no keyboard focus |
| [WlrLayershell](https://quickshell.org/docs/v0.3.1/types/Quickshell.Wayland/WlrLayershell/) | Layer selection and stable namespace |
| [SystemClock](https://quickshell.org/docs/v0.3.1/types/Quickshell/SystemClock/) | Minute precision and native date value |
| [Upstream Lua integration change](https://git.outfoxxed.me/quickshell/quickshell/commit/01834e9c8feb5fecdf7e7973ac116f3e3befc26e?files=src/wayland) | Native workspace activation adapts syntax and quotes Lua names |
| [Upstream CLI parser](https://git.outfoxxed.me/quickshell/quickshell/src/commit/8d19beb69ea72585b93d0ec94168d0bf25f1bd68/src/launch/parsecommand.cpp) | Explicit path selection and configuration-scoped process commands |
| [Hyprland current FAQ](https://wiki.hypr.land/faq/) | Startup callback in `hyprland.lua` |
| [Hyprland Lua utilities](https://wiki.hypr.land/configuring/core/advanced-configuration/lua-utilities/) | `hl.exec_cmd` is asynchronous |
| [swaylock README](https://github.com/swaywm/swaylock) | Works on any compositor implementing ext-session-lock-v1 |
| [hyprlock README](https://github.com/hyprwm/Hyprlock) | Uses the ext-session-lock protocol; no option to return once locked is documented |
| [ext-session-lock-v1 (wayland.app)](https://wayland.app/protocols/ext-session-lock-v1) | Protocol listed as supported by Hyprland and Sway |
| [Mango key bindings](https://mangowm.github.io/docs/bindings/keys) | Mango's own example binds `swaylock` |
| `docs/evidence/compositor-includes/` | Hyprland 0.57 loads Lua's standard libraries (`dofile`); Mango 0.18.4 parses `source_optional` without requiring the file |

The guide and several type pages consulted are from 0.3.1; the 0.3.2 changelog
and Hyprland pages were checked for the newer compositor compatibility change.
Documentation/source review is not a substitute for a live smoke test.

## Portable build and optional greeter

Additional primary documentation/source consulted on 2026-10-31:

| Source | Decision informed |
| --- | --- |
| [Mango 0.18.4 source](https://github.com/mangowm/mango/tree/0.18.4) | Built real compositor/mmsg; actual IPC JSON fields, NDJSON watch lifecycle, overview/tag behaviour, dispatch syntax and parser keys |
| [Mango mmsg documentation](https://github.com/mangowm/mango/blob/0.18.4/docs/ipc.md) | get/watch/dispatch interface; versioned source used to resolve exact schema |
| [Quickshell native Greetd](https://quickshell.org/docs/v0.3.2/types/Quickshell.Services.Greetd/Greetd/) | PAM prompts, cancellation, readyToLaunch and launch/automatic exit |
| [greetd IPC protocol](https://man.sr.ht/~kennylevinsen/greetd/) | Length-prefixed JSON, auth/session separation, prompt responses, cancellation and prompt greeter exit |
| [greetd protocol source](https://git.sr.ht/~kennylevinsen/greetd/tree/master/item/greetd_ipc/src/lib.rs) | Exact auth_message_type/auth_message field names, request/reply enumeration |
| [greetd daemon source](https://git.sr.ht/~kennylevinsen/greetd/tree/master/item/greetd/src/context.rs) | Normal cancel success response and session-start lifecycle |
| [Desktop Entry specification](https://specifications.freedesktop.org/desktop-entry-spec/latest/) | Exec/TryExec/session metadata; argv field expansion rather than shell evaluation |
| [Quickshell Pipewire](https://quickshell.org/docs/v0.3.2/types/Quickshell.Services.Pipewire/) | Native node tracking, audio/mute and preferred defaults |
| [Quickshell Networking](https://quickshell.org/docs/v0.3.2/types/Quickshell.Networking/) | Native scanner, network state/connection API and failures |
| [Quickshell Bluetooth](https://quickshell.org/docs/v0.3.2/types/Quickshell.Bluetooth/) | Adapter/device pairing and power state; existing agent boundary |
| [Quickshell MPRIS](https://quickshell.org/docs/v0.3.2/types/Quickshell.Services.Mpris/) | Capability-aware media controls |
| [Quickshell system tray](https://quickshell.org/docs/v0.3.2/types/Quickshell.Services.SystemTray/) | Native SNI and menu lifecycle |
| [Quickshell notifications](https://quickshell.org/docs/v0.3.2/types/Quickshell.Services.Notifications/) | Tracked notification model, action invocation/expiry and persistence boundary |

Research establishes API intent. The development report separately records what
actually executed. In particular, neither source review nor protocol fixtures are
reported as successful native compositor/PAM integration.
