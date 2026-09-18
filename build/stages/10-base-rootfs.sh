#!/usr/bin/env bash
# Stage 10 - Alpine minirootfs, trimmed to the base budget
source "$(dirname "$0")/../lib/common.sh"

MINI="$WORK/cache/alpine-minirootfs-$ARCH.tar.gz"
URL="https://dl-cdn.alpinelinux.org/alpine/$ALPINE_BRANCH/releases/$ARCH"

[ -f "$MINI" ] || {
	step "fetching Alpine minirootfs"
	file=$(curl -s "$URL/" | grep -o "alpine-minirootfs-[0-9.]*-$ARCH.tar.gz" | head -1)
	curl -fL "$URL/$file" -o "$MINI"
}

rm -rf "$ROOTFS"; mkdir -p "$ROOTFS"
tar -xzf "$MINI" -C "$ROOTFS"

cp /etc/resolv.conf "$ROOTFS/etc/resolv.conf"
grep -v '^#' "$(dirname "$0")/../packages/base.txt" | grep -v '^$' > "$WORK/pkgs.txt"

step "installing base packages into the rootfs"
sudo chroot "$ROOTFS" /sbin/apk add --no-cache $(tr '\n' ' ' < "$WORK/pkgs.txt")

step "trimming"
sudo rm -rf "$ROOTFS"/usr/share/{man,doc,info,licenses,zoneinfo/right}
sudo rm -rf "$ROOTFS"/var/cache/apk/*
# One font family, western subset only. Emoji fonts alone are 8-10 MiB.
sudo find "$ROOTFS/usr/share/fonts" -type f ! -name 'Inter*' -delete 2>/dev/null || true
sudo find "$ROOTFS" -name '*.a' -delete

# Androws user, no password, no shell login
sudo chroot "$ROOTFS" /usr/sbin/addgroup -g 1000 androws
sudo chroot "$ROOTFS" /usr/sbin/adduser -D -u 1000 -G androws -h /home/androws androws
for g in video input audio seat; do sudo chroot "$ROOTFS" /usr/sbin/addgroup androws $g || true; done

budget "base rootfs" "$(mib "$ROOTFS")" 72
