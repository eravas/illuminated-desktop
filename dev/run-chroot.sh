#!/usr/bin/env bash
# Run a command in the Arch runtime built by dev/cloud-setup.sh, without Docker.
# Same contract as dev/run.sh and dev/run-vfs.sh: no network, UID 1000, private
# tmp/run/shm/home, the project read/write at /project, the runtime itself read-only.
# Needs root (mount and PID namespaces); run as root on the cloud host.
set -euo pipefail
cd "$(dirname "$0")/.."
root=${ILLUMINATED_ROOTFS:-/opt/arch/root.x86_64}
[[ -x $root/usr/bin/quickshell ]] || { echo "no runtime at $root; run dev/cloud-setup.sh" >&2; exit 1; }
[[ $# -gt 0 ]] || set -- bash
mkdir -p artifacts
# The tests write into the project as UID 1000 (artifacts, the pointer helper).
[[ $(stat -c %u .) == 1000 ]] || chown -R 1000:1000 .
exec unshare --mount --net --pid --fork --mount-proc=/proc bash -euo pipefail -c '
root=$1 project=$2; shift 2
mount --make-rprivate /
mount --bind "$root" "$root"
mount -o remount,bind,ro "$root"
mount -t proc proc "$root/proc"
mount -t tmpfs -o mode=755 dev "$root/dev"
for d in null zero urandom random tty; do touch "$root/dev/$d"; mount --bind /dev/$d "$root/dev/$d"; done
ln -s /proc/self/fd "$root/dev/fd"
mkdir -p "$root/dev/shm" "$root/dev/pts"
mount -t tmpfs -o mode=1777,size=256m shm "$root/dev/shm"
mount -t tmpfs -o mode=1777,exec tmp "$root/tmp"
mount -t tmpfs -o mode=1777 run "$root/run"
mount -t tmpfs -o uid=1000,gid=1000,mode=700 home "$root/home/tester"
mount --bind "$project" "$root/project"
ip link set lo up 2>/dev/null || true
if [[ ! -x $root/project/tests/runtime/native/pointer ]]; then
  chroot --userspec=1000:1000 "$root" /usr/bin/env -i PATH=/usr/bin HOME=/tmp bash /project/dev/build-pointer.sh
fi
exec chroot --userspec=1000:1000 "$root" /usr/bin/env -i \
  PATH=/usr/local/bin:/usr/bin LANG=C.UTF-8 HOME=/home/tester USER=tester \
  QT_QPA_PLATFORM=wayland QT_QUICK_BACKEND=software LIBGL_ALWAYS_SOFTWARE=1 \
  /bin/bash -c "cd /project; exec \"\$@\"" bash "$@"
' bash "$root" "$PWD" "$@"
