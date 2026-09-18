#!/usr/bin/env bash
# Stage 30 - turn a GSI into the Droid runtime
source "$(dirname "$0")/../lib/common.sh"
need_input system.img

GSI="$WORK/input/system.img"
MNT="$WORK/gsi-mnt"
DROID="$WORK/droid"

step "unpacking the GSI"
mkdir -p "$MNT" "$DROID"
sudo mount -o ro,loop "$GSI" "$MNT" || die "cannot mount $GSI (is it a raw ext4 GSI?)"
sudo cp -a "$MNT"/. "$DROID"/
sudo umount "$MNT"

step "stripping what a 610 MiB budget cannot carry"
# Bundled apps, test artefacts, unused ABIs, and every locale but English. This is
# where the difference between a 1.4 GiB GSI and a 610 MiB runtime comes from.
sudo rm -rf "$DROID"/system/app/{Browser2,Camera2,Gallery2,Music,QuickSearchBox,WallpaperPicker}
sudo rm -rf "$DROID"/system/priv-app/{CalendarProvider,Traceur,StatementService}
sudo rm -rf "$DROID"/system/{fonts/NotoColorEmoji.ttf,usr/srec,media/audio/ringtones}
sudo rm -rf "$DROID"/system/lib/arm "$DROID"/system/lib64/arm64  # host-arch only
sudo find "$DROID" -name '*.odex' -delete
sudo find "$DROID" -name 'test*' -path '*/bin/*' -delete

step "wiring the Androws container props"
sudo tee "$DROID/system/build.prop.androws" >/dev/null <<'PROPS'
# Androws container overrides
ro.androws.runtime=droid
ro.config.low_ram=true
ro.lmk.critical_upgrade=true
ro.lmk.downgrade_pressure=40
dalvik.vm.heapgrowthlimit=64m
dalvik.vm.heapsize=128m
dalvik.vm.dex2oat-filter=speed-profile
debug.sf.nobootanimation=1
ro.surface_flinger.max_frame_buffer_acquired_buffers=2
PROPS
sudo sh -c "cat '$DROID/system/build.prop.androws' >> '$DROID/system/build.prop'"

step "compressing"
mkdir -p "$ROOTFS/usr/lib/androws"
sudo mksquashfs "$DROID" "$ROOTFS/usr/lib/androws/droid.sfs" \
	-comp zstd -Xcompression-level 19 -b 256K -noappend -quiet

# TODO(0.2): the hwcomposer shim. Until it lands the container renders in software,
# which works and is slow, and is marked as stubbed in docs/ROADMAP.md.
sudo install -Dm0755 /dev/stdin "$ROOTFS/usr/lib/androws/droid-start" <<'START'
#!/bin/sh
# Bring up the Droid container inside its own namespaces and cgroup.
set -eu
mkdir -p /run/androws/droid
mount -t squashfs -o loop,ro /usr/lib/androws/droid.sfs /run/androws/droid
echo $$ > /sys/fs/cgroup/androws/droid/cgroup.procs
exec unshare --mount --pid --fork --user --map-root-user \
	chroot /run/androws/droid /init androws
START

budget "droid runtime" "$(mib "$ROOTFS/usr/lib/androws/droid.sfs")" 640
