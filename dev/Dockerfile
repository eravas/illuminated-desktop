# Pinned official Arch base; keep installation and user creation in one layer
# to avoid full filesystem copies with Docker VFS.
FROM archlinux:base@sha256:e82623936fa1a69700b48e98b058df6eaab18b737c27473a7234a40fdecb9413
# Keep a dated Arch repository for a coherent Qt/Quickshell ABI.
ARG ARCH_DATE=2026/10/30
RUN --mount=type=secret,id=proxy_ca,required=true,mode=0444 \
    SSL_CERT_FILE=/run/secrets/proxy_ca bash -euxc '\
    printf "Server = https://archive.archlinux.org/repos/%s/\u0024repo/os/\u0024arch\n" "$1" > /etc/pacman.d/mirrorlist; \
    printf "\nXferCommand = /usr/bin/curl --fail --cacert /run/secrets/proxy_ca -L -o %%o %%u\n" > /tmp/xfer; sed -i "/^\\[options\\]/r /tmp/xfer" /etc/pacman.conf; \
    pacman -Syu --noconfirm quickshell qt6-declarative qt6-tools gcc pkgconf meson ninja cjson scenefx pipewire wireplumber python-dbus-next hyprland sway weston mesa dbus python nodejs xorg-xwayland grim wtype wayland-utils brightnessctl udisks2 wl-clipboard cliphist xdg-utils; \
    pacman -Q > /opt/packages.txt; \
    rm -rf /var/cache/pacman/pkg/*; \
    useradd -m -u 1000 tester; mkdir /project' bash "$ARCH_DATE"
USER tester
ENV QT_QPA_PLATFORM=wayland QT_QUICK_BACKEND=software LIBGL_ALWAYS_SOFTWARE=1
CMD ["bash"]
