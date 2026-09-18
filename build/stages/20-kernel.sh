#!/usr/bin/env bash
# Stage 20 - kernel with binderfs, zram, squashfs, overlayfs
source "$(dirname "$0")/../lib/common.sh"

SRC="$WORK/cache/linux-$KERNEL_VER"
TAR="$WORK/cache/linux-$KERNEL_VER.tar.xz"

[ -d "$SRC" ] || {
	[ -f "$TAR" ] || curl -fL "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-$KERNEL_VER.tar.xz" -o "$TAR"
	tar -xf "$TAR" -C "$WORK/cache"
}

cd "$SRC"
make -s defconfig
./scripts/kconfig/merge_config.sh -m .config "$(dirname "$0")/../kernel/androws.config" >/dev/null
make -s olddefconfig

step "compiling $KERNEL_VER (this is the slow part)"
make -s -j"$(nproc)" bzImage modules

mkdir -p "$ROOTFS/boot"
cp arch/x86/boot/bzImage "$ROOTFS/boot/vmlinuz-androws"
make -s INSTALL_MOD_PATH="$ROOTFS" INSTALL_MOD_STRIP=1 modules_install

# The initramfs only has to find the squashfs and pivot into the overlay.
"$(dirname "$0")/../lib/mkinitramfs.sh" "$ROOTFS" "$ROOTFS/boot/initramfs-androws" 2>/dev/null || \
	step "initramfs helper not present yet, stage 60 will build a direct-boot image"

budget "kernel + modules" "$(mib "$ROOTFS/boot")" 14
