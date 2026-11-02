#!/usr/bin/env bash
# Cloud VFS fallback: mount an existing image filesystem read-only, never mutate it.
set -euo pipefail
cd "$(dirname "$0")/.."
runtime=${ILLUMINATED_ROOTFS:-/workspace/arch-runtime}
docker run --rm --network none --read-only --pid=host \
 -v /usr:/usr:ro -v /lib:/lib:ro -v /lib64:/lib64:ro \
 -v "$runtime:/arch:ro" -v "$PWD:/arch/project" \
 -v /proc:/arch/proc:ro \
 -v /dev/null:/arch/dev/null -v /dev/zero:/arch/dev/zero \
 -v /dev/urandom:/arch/dev/urandom -v /dev/random:/arch/dev/random \
 --tmpfs /arch/dev/shm:mode=1777,size=256m --tmpfs /arch/tmp:exec,mode=1777 --tmpfs /arch/run:mode=1777 \
 --tmpfs /arch/home/tester:uid=1000,gid=1000 \
 -e LANG=C.UTF-8 -e HOME=/home/tester -e QT_QPA_PLATFORM=wayland \
 -e QT_QUICK_BACKEND=software -e LIBGL_ALWAYS_SOFTWARE=1 \
 --entrypoint /usr/sbin/chroot illuminated-export-helper \
 --userspec=1000:1000 /arch /bin/bash -c 'cd /project; exec "$@"' bash "$@"
