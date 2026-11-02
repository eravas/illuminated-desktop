#!/usr/bin/env bash
# Inside the Arch dev image, with the pinned archive already fetched on the host.
set -euo pipefail
cd /project
archive=${1:-/project/dev/cache/mango-0.18.4.tar.gz}
printf '%s  %s\n' e4ec09a020b8227dc7044cf9e16f4563d28a24d99a08a51aed05cc8b95cbbbfa "$archive" | sha256sum -c -
work=$(mktemp -d)
tar -xzf "$archive" -C "$work"
meson setup "$work/build" "$work/mango-0.18.4" -Dxwayland=disabled --buildtype=release
meson compile -C "$work/build" -j2
cp "$work/build/mango" "$work/build/mmsg" /project/dev/
