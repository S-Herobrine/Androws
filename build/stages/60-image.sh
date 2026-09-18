#!/usr/bin/env bash
# Stage 60 - pack the image and enforce the budgets
source "$(dirname "$0")/../lib/common.sh"

IMG="$OUT/androws-$VERSION-$ARCH.img"
SYS="$WORK/system.sfs"

step "compressing the system"
sudo mksquashfs "$ROOTFS" "$SYS" -comp zstd -Xcompression-level 19 -b 256K -noappend -quiet \
	-e "$ROOTFS/boot"

sys_mib=$(mib "$SYS")
budget "system partition" "$sys_mib" 880
budget "droid image"      "$(mib "$ROOTFS/usr/lib/androws/droid.sfs")" 640

# The memory prediction is a static sum, deliberately pessimistic: it is the table in
# docs/BUDGETS.md with the foreground runtime pinned to the Droid case.
peak=$(( 45 + 10 + 28 + 12 + 18 + 330 + 15 ))
[ "$peak" -le 480 ] || die "predicted peak memory ${peak} MiB exceeds 480 MiB"
ok "predicted peak memory ${peak}/480 MiB"

step "partitioning"
rm -f "$IMG"; truncate -s 1000M "$IMG"
parted -s "$IMG" mklabel gpt \
	mkpart esp fat32 1MiB 33MiB \
	mkpart system 33MiB $(( 33 + sys_mib ))MiB \
	mkpart userdata $(( 33 + sys_mib ))MiB 100% \
	set 1 esp on

loop=$(sudo losetup --find --show --partscan "$IMG")
trap 'sudo losetup -d "$loop" 2>/dev/null || true' EXIT

sudo mkfs.vfat -F32 -n ANDROWS-ESP "${loop}p1" >/dev/null
sudo dd if="$SYS" of="${loop}p2" bs=4M status=none
sudo mkfs.f2fs -f -l androws-data "${loop}p3" >/dev/null

step "boot files"
esp="$WORK/esp"; sudo mkdir -p "$esp"; sudo mount "${loop}p1" "$esp"
sudo mkdir -p "$esp/EFI/BOOT" "$esp/androws"
sudo cp "$ROOTFS/boot/vmlinuz-androws" "$esp/androws/vmlinuz"
[ -f "$ROOTFS/boot/initramfs-androws" ] && sudo cp "$ROOTFS/boot/initramfs-androws" "$esp/androws/initramfs"
sudo tee "$esp/loader.conf" >/dev/null <<'LC'
default androws
timeout 0
LC
sudo umount "$esp"

ok "image at $IMG ($(du -h "$IMG" | cut -f1))"
