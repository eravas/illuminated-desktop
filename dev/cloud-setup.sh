#!/usr/bin/env bash
# Build the Arch test runtime on a non-Arch, Docker-less host (for example a Claude Code
# cloud container: Ubuntu 24.04, root, full capabilities, HTTPS through a proxy).
#
# Self-contained on purpose: it can be pasted as an environment setup script, which runs
# before the repository is available. It produces the userspace dev/Dockerfile describes
# (same dated archive, same packages; tests/test_cloud_runtime.py keeps them in sync) as a
# plain directory, plus unmodified Mango/mmsg 0.18.4 in its /usr/local/bin.
# dev/run-chroot.sh then runs commands inside it as UID 1000.
#
#   bash dev/cloud-setup.sh                     # as root; idempotent; ~3 GB, ~6 minutes
#   bash dev/run-chroot.sh bash dev/test-all.sh
#
# Environment: ILLUMINATED_ROOTFS (default /opt/arch/root.x86_64); SSL_CERT_FILE for a
# re-terminating proxy's CA; HTTPS_PROXY. TLS and pacman signature checks stay on.
set -euo pipefail
ARCH_DATE=2026/10/30
BOOTSTRAP=2026.10.01
PACKAGES="quickshell qt6-declarative qt6-tools gcc pkgconf meson ninja cjson scenefx pipewire wireplumber python-dbus-next hyprland sway weston mesa dbus python nodejs xorg-xwayland grim wtype wayland-utils brightnessctl udisks2 wl-clipboard cliphist xdg-utils"
MANGO_TAG=0.18.4
MANGO_SHA256=e4ec09a020b8227dc7044cf9e16f4563d28a24d99a08a51aed05cc8b95cbbbfa

root=${ILLUMINATED_ROOTFS:-/opt/arch/root.x86_64}
ca=${SSL_CERT_FILE:-/etc/ssl/certs/ca-certificates.crt}
[[ -f $ca ]] || ca=/etc/ssl/certs/ca-certificates.crt
need() { command -v "$1" >/dev/null || { apt-get update -q && apt-get install -y -q "$2"; }; }
need zstd zstd
need curl curl
need git git

if [[ ! -x $root/usr/bin/pacman ]]; then
  base=$(dirname "$root")
  mkdir -p "$base"
  name=archlinux-bootstrap-$BOOTSTRAP-x86_64.tar.zst
  url=https://archive.archlinux.org/iso/$BOOTSTRAP
  curl -fsSL -o "$base/$name" "$url/$name"
  (cd "$base" && curl -fsSL "$url/sha256sums.txt" | grep " $name\$" | sha256sum -c -)
  tar --zstd -xf "$base/$name" -C "$base" --numeric-owner 2>/dev/null
  rm -f "$base/$name"
  [[ $base/root.x86_64 == "$root" ]] || mv "$base/root.x86_64" "$root"
fi

mounted=()
cleanup() { for ((i=${#mounted[@]}-1; i>=0; i--)); do umount -l "${mounted[i]}" 2>/dev/null || true; done; }
trap cleanup EXIT
mount -t proc proc "$root/proc"; mounted+=("$root/proc")
for d in dev sys; do mount --bind "/$d" "$root/$d"; mounted+=("$root/$d"); done
cp -L /etc/resolv.conf "$root/etc/resolv.conf" 2>/dev/null || true
install -Dm644 "$ca" "$root/etc/illuminated-host-ca.crt"

printf 'Server = https://archive.archlinux.org/repos/%s/$repo/os/$arch\n' "$ARCH_DATE" > "$root/etc/pacman.d/mirrorlist"
if ! grep -q illuminated-host-ca "$root/etc/pacman.conf"; then
  # A re-terminating proxy needs its CA; pacman's built-in downloader cannot be pointed at
  # one, so use curl. The download user and sandbox need kernel features a chroot lacks.
  sed -i '/^\[options\]/a XferCommand = /usr/bin/curl -sS --fail --cacert /etc/illuminated-host-ca.crt -L -C - -o %o %u\nDisableSandbox' "$root/etc/pacman.conf"
  sed -i 's/^CheckSpace/#CheckSpace/; s/^DownloadUser/#DownloadUser/' "$root/etc/pacman.conf"
fi

run() { chroot "$root" /usr/bin/env -i PATH=/usr/local/bin:/usr/bin HOME=/root LANG=C.UTF-8 \
  HTTPS_PROXY="${HTTPS_PROXY:-}" https_proxy="${HTTPS_PROXY:-}" "$@"; }

if [[ ! -s $root/etc/pacman.d/gnupg/pubring.gpg ]]; then
  run pacman-key --init
  run pacman-key --populate archlinux
fi
# shellcheck disable=SC2086
run pacman -Syu --noconfirm --needed $PACKAGES >/dev/null
run sh -c 'pacman -Q > /opt/packages.txt; rm -rf /var/cache/pacman/pkg/*'
run sh -c 'id tester >/dev/null 2>&1 || useradd -m -u 1000 tester; mkdir -p /project'

# Mango/mmsg for the adapter suite. GitHub's archive endpoint may be blocked where git
# is not; `git archive | gzip -n` reproduces the release tarball byte for byte.
if [[ ! -x $root/usr/local/bin/mmsg ]]; then
  src=$(mktemp -d)
  git clone -q --depth 1 --branch "$MANGO_TAG" https://github.com/mangowm/mango.git "$src/git" 2>/dev/null
  git -C "$src/git" archive --format=tar --prefix="mango-$MANGO_TAG/" HEAD | gzip -n > "$root/tmp/mango.tar.gz"
  echo "$MANGO_SHA256  $root/tmp/mango.tar.gz" | sha256sum -c -
  rm -rf "$src"
  run sh -euc "w=\$(mktemp -d); tar -xzf /tmp/mango.tar.gz -C \$w
    meson setup \$w/build \$w/mango-$MANGO_TAG -Dxwayland=disabled --buildtype=release >/dev/null
    meson compile -C \$w/build -j\$(nproc) >/dev/null
    install -m755 \$w/build/mango \$w/build/mmsg /usr/local/bin/; rm -rf \$w /tmp/mango.tar.gz"
fi
echo "Arch runtime ready at $root: $(run pacman -Q quickshell), $(run sh -c 'command -v mmsg')"
