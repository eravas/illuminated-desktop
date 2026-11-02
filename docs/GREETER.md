# Optional animated greetd greeter — experimental

This component is independent of the in-session rice. Ly, SDDM and other display
managers continue working without it. The rice installer copies its source but
never configures/enables greetd or replaces a display manager.

## Lifecycle and implementation

`quickshell/greeter.qml` runs one login surface in a private Wayland compositor.
The background appears first. A roll starts entirely beyond the right edge,
reveals the flat sheet leftward, then exposes session/username/authentication
controls. Failed authentication leaves it open. Successful authentication clears
the response, retracts the sheet to the right, then sends start_session. The
native Quickshell client exits promptly after the successful launch reply;
`integration/greetd/ui.example` then exits the private Sway compositor so greetd
can start the selected user session. A non-seamless transition is accepted.

Quickshell's native Greetd API implements the length-prefixed JSON protocol:
create_session, authentication prompts/responses, cancel_session and
start_session. PAM and greetd own authentication. The UI supports echo and secret
prompts rather than assuming a single password. `readyToLaunch` separates
authentication success from final session launch; **animation is before launch**,
not after an acknowledged start_session. Launch errors reopen the sheet.

Escape/cancel aborts before launch. F2 skips motion. A bounded watchdog proceeds
after authentication if retraction stalls. Authentication has a configurable
timeout. No animation is allowed to trap an authenticated login indefinitely.
No custom password verification, credential persistence or secret logging is
implemented. Inputs clear immediately after response submission, cancellation,
failure and success. Qt/native transport necessarily holds transient strings;
this is not a claim of memory-zeroization. Never use WAYLAND_DEBUG or typed-input
traces on a real authentication session.

## Session and code trust

`sessions.py` discovers installed .desktop metadata in
`/usr/local/share/wayland-sessions` and `/usr/share/wayland-sessions`. It accepts
installed supported Hyprland/Mango sessions, checks executable/TryExec presence,
expands supported Exec field codes into an argument array and does not launch a
shell itself. Production requires root-owned, non-group/world-writable metadata
and ancestor paths. No user-writable custom session directory is accepted.
`--fixtures` exists only for tests.

All greeter code, QML, wrappers, compositor configuration and optional theme must
be deployed root-owned and non-writable by the greeter user. The source checkout
or normal personal rice installation is **not** an appropriate real login path.
The wrappers clear test-session environment variables. Production sets
ILLUMINATED_GREETER=1, so Settings does not read/write personal preference files.
An optional ILLUMINATED_GREETER_THEME must point to administrator-trusted JSON.

## Validation and limitations

The actual QML surface rendered under headless Sway. An explicit socket fixture
exercised the **native Quickshell framed greetd client** with simulated challenge,
rejection, retry, secret clearing, cancel during retraction, session-start failure,
and a deliberately stalled animation followed by watchdog launch. `/bin/true`
was merely captured as the requested fixture session; it was never launched by
the fixture. No real greetd daemon, PAM, account authentication, seat/VT handoff
or user compositor session was tested. The trusted metadata parser has unit tests.

Known upstream Quickshell 0.3.2 behaviour: cancelSession moves to Inactive before
greetd's normal success acknowledgement arrives. The client logs
`Received unexpected greetd response success`. The test uses the real protocol's
success reply and verifies recovery; it does not fabricate an error to silence
the warning. A real greetd acceptance run and preferably an upstream fix/newer
Quickshell are required before trusting this optional greeter for routine login.

## Deliberate administrator opt-in

Examples under `integration/greetd/` show the configuration boundary, not an
installer. Do not enable this as your only login path yet. Review greetd's current
PAM/seat setup and your distribution's service units. A correct XDG_RUNTIME_DIR
for the dedicated greeter user is required. Root-owned deployment would place:

- The complete QML tree in `/usr/share/illuminated-greeter`.
- Reviewed executable start/ui wrappers in `/usr/lib/illuminated-greeter`.
- Private Sway configuration in `/etc/illuminated-greeter/sway.conf`.
- A deliberately merged greetd configuration under `/etc/greetd`.

Keep the previous DM configuration and an independent working text console.
F12 exits the example private compositor; that alone is **not** a text-login
fallback. Before any graphical opt-in, verify a separate TTY login and a reviewed
agreety/text-greeter configuration. If the graphical greeter crashes or fails,
switch to that TTY and restore the known-good greetd text command or previous DM
using your system's normal service management. Avoid enabling competing DMs.
After physical tests, document actual PAM cancellation, timeout, multi-prompt,
session-failure, crash/restart and VT/session handoff behaviour before adoption.

For safe preview only, stop the ordinary shell and run a separate process with
`ILLUMINATED_GREETER=1 quickshell -p /absolute/project/quickshell/greeter.qml`
without GREETD_SOCK. It displays an unavailable/preview message and performs no
authentication. Never point the automated fixture at a real greetd socket.
