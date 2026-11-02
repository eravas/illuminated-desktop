#!/usr/bin/env bash
# Run inside the image. Preserve failures: a failed probe is not an integration pass.
set -u
cd /project
export XDG_RUNTIME_DIR=$(mktemp -d)
chmod 700 "$XDG_RUNTIME_DIR"
trap 'kill "${parent:-}" 2>/dev/null || true; rm -rf "$XDG_RUNTIME_DIR"' EXIT
export WLR_BACKENDS=headless WLR_RENDERER=pixman WLR_LIBINPUT_NO_DEVICES=1
export WAYLAND_DISPLAY=wayland-1
cp "$(command -v sway)" "$XDG_RUNTIME_DIR/sway"
"$XDG_RUNTIME_DIR/sway" -c dev/sway.conf > artifacts/hyprland-parent.log 2>&1 &
parent=$!
for ((i=0; i<100; i++)); do
 [[ -S $XDG_RUNTIME_DIR/$WAYLAND_DISPLAY ]] && break
 kill -0 "$parent" || exit 1
 sleep .1
done
set +e
timeout 15s env AQ_BACKEND=wayland LIBGL_ALWAYS_SOFTWARE=1 WLR_RENDERER_ALLOW_SOFTWARE=1 \
 Hyprland --config /project/dev/hyprland.lua > artifacts/hyprland-nested.log 2>&1
nested=$?
timeout 15s env -u WAYLAND_DISPLAY AQ_BACKEND=headless LIBGL_ALWAYS_SOFTWARE=1 \
 Hyprland --config /project/dev/hyprland.lua > artifacts/hyprland-headless.log 2>&1
headless=$?
find "$XDG_RUNTIME_DIR/hypr" -name hyprland.log -exec cp --parents '{}' /project/artifacts/ \;
printf 'nested exit=%s; headless exit=%s (124 means timeout, inspect readiness logs)\n' "$nested" "$headless" | tee artifacts/hyprland-probe.txt
