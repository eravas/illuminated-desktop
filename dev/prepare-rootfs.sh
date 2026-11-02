#!/usr/bin/env bash
# Prepare an extracted, task-owned rootfs for the read-only chroot runner.
set -euo pipefail
runtime=${ILLUMINATED_ROOTFS:-/workspace/arch-runtime}
[[ -x $runtime/usr/bin/quickshell ]]
mkdir -p "$runtime/dev/shm"
for device in null zero urandom random; do
 [[ -e $runtime/dev/$device ]] || touch "$runtime/dev/$device"
done
[[ -e $runtime/dev/fd || -L $runtime/dev/fd ]] || ln -s /proc/self/fd "$runtime/dev/fd"
python3 - <<'PY'
import io, subprocess, tarfile
archive = io.BytesIO()
with tarfile.open(fileobj=archive, mode='w'):
    pass
subprocess.run(['docker', 'import', '-', 'illuminated-export-helper'], input=archive.getvalue(), check=True)
PY
