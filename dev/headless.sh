#!/usr/bin/env bash
set -euo pipefail
cd /project
export XDG_RUNTIME_DIR=$(mktemp -d)
chmod 700 "$XDG_RUNTIME_DIR"
trap 'kill "${compositor:-}" 2>/dev/null || true; rm -rf "$XDG_RUNTIME_DIR"' EXIT
export WLR_BACKENDS=headless WLR_RENDERER=pixman WLR_LIBINPUT_NO_DEVICES=1
export WAYLAND_DISPLAY=wayland-1
cp "$(command -v sway)" "$XDG_RUNTIME_DIR/sway"
"$XDG_RUNTIME_DIR/sway" -c dev/sway.conf > artifacts/sway.log 2>&1 &
compositor=$!
for ((i=0; i<100; i++)); do
 [[ -S $XDG_RUNTIME_DIR/$WAYLAND_DISPLAY ]] && break
 kill -0 "$compositor" || { cat artifacts/sway.log; exit 1; }
 sleep .1
done
export SWAYSOCK=$(find "$XDG_RUNTIME_DIR" -name 'sway-ipc*.sock' -print -quit)
if [[ $# -gt 0 ]]; then "$@"; else python tests/runtime/run.py; fi
