# Existing MPD / rmpc integration

MPD is a music server and rmpc is its client. Neither is assumed to expose MPRIS.
The shell consumes reusable native Quickshell MPRIS objects; it does not parse rmpc
output or replace the existing music setup.

The pinned official Arch repository contains `mpd-mpris` 0.4.4-1. Its actual
`--help` output was inspected and retained in artifacts/development/mpd-mpris-help.txt.
Install it only if you do not already run a working MPD MPRIS bridge:

```sh
sudo pacman -S mpd-mpris
mpd-mpris -host localhost -port 6600 -no-instance
```

Use the address and port of the **existing** server. For an existing Unix socket:

```sh
mpd-mpris -network unix -host /your/existing/mpd/socket -no-instance
```

Run the bridge in the same user/session D-Bus environment as Quickshell. For a
password-protected server, use the supported `-pwd-file` path with private file
permissions; avoid putting a password on the command line. No bridge or MPD
service is enabled automatically. Keep it in a foreground terminal for the first
test, then integrate it with your existing startup method if desired. Do not add
a duplicate bridge when another MPRIS implementation already works.

Open the media sheet and select the exposed player. Test track changes, pause,
next/previous and seeking with rmpc open too. The bridge may have different seek
capabilities; unavailable native capabilities disable controls. Multiple MPRIS
players can be selected explicitly; otherwise a playing player is preferred.

The command-line inspection and MPRIS protocol tests do not establish actual MPD
playback integration. That acceptance check still belongs on the physical setup.
